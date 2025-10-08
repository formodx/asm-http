%include "externs.asm"
%include "constants.asm"
%define BUFFER_SIZE 8192
%define RESPONSE_BODY_SIZE 32768


%macro load_string 1
    %strlen length %1

    %assign i 0
    %assign x (length+7) / 8 + 1
    %rep x
        mov qword [string + i], 0
        %assign i i + 8
    %endrep

    %assign i 1
    %assign x (length+3) / 4
    %rep x
        %assign j i - 1
        %substr _string %1 i, 4
        mov dword [string + j], _string
        %assign i i+4
    %endrep
%endmacro


global main


section .text
    %define argc rbp - 4
    %define argv rbp - 12
    %define server_port rbp - 14
    %define optval rbp - 18
    main:
        push rbp
        mov rbp, rsp
        sub rsp, 32

        mov dword [argc], edi
        mov qword [argv], rsi
        mov dword [optval], 1

        cmp edi, 2
        je .skip1
            mov rdi, STDERR_FILENO
            load_string `usage: %s <port>\n`
            lea rsi, [string]
            mov rax, qword [argv]
            mov rdx, qword [rax]
            call dprintf

            mov rdi, 1
            call exit
        .skip1 equ $

        lea rdi, [current_working_directory]
        mov rsi, PATH_MAX
        call getcwd

        mov rdi, STDOUT_FILENO
        load_string `current working directory: %s\n`
        lea rsi, [string]
        lea rdx, [current_working_directory]
        call dprintf

        mov rax, qword [argv]
        add rax, 8
        mov rdi, qword [rax]
        mov rsi, NULL
        mov rdx, 10
        call strtol

        mov word [server_port], ax

        mov rdi, STDOUT_FILENO
        load_string `server port: %d\n`
        lea rsi, [string]
        movzx rdx, ax
        call dprintf

        mov rdi, AF_INET
        mov rsi, SOCK_STREAM
        mov rdx, IPPROTO_IP
        call socket
        mov dword [server_fd], eax

        load_string `server socket`
        lea rdi, [string]
        call exit_on_error

        mov edi, dword [server_fd]
        mov rsi, SOL_SOCKET
        mov rdx, SO_REUSEADDR
        lea rcx, [optval]
        mov r8, 4
        call setsockopt

        load_string `server setsockopt`
        lea rdi, [string]
        call exit_on_error

        movzx rdi, word [server_port]
        call htons

        mov word [server_addr], AF_INET
        mov word [server_addr + 2], ax

        mov edi, dword [server_fd]
        lea rsi, [server_addr]
        mov rdx, 16
        call bind

        load_string `server bind`
        lea rdi, [string]
        call exit_on_error

        mov edi, dword [server_fd]
        mov rsi, 5
        call listen

        load_string `server listen`
        lea rdi, [string]
        call exit_on_error

        .loop:
            mov edi, dword [server_fd]
            lea rsi, [client_addr]
            lea rdx, [client_len]
            call accept
            mov dword [client_fd], eax

            load_string `server accept`
            lea rdi, [string]
            call exit_on_error

            lea rdi, [buffer]
            mov rsi, 0
            mov rdx, BUFFER_SIZE
            call memset

            mov edi, dword [client_fd]
            lea rsi, [buffer]
            mov rdx, BUFFER_SIZE - 1
            mov rcx, 0
            call recv

            load_string `client recv`
            lea rdi, [string]
            call exit_on_error

            call handle_request

            mov edi, dword [client_fd]
            call close

            load_string `client close`
            lea rdi, [string]
            call exit_on_error

            jmp .loop

        mov edi, dword [server_fd]
        call close

        load_string `server close`
        lea rdi, [string]
        call exit_on_error

        mov rax, 0
        leave
        ret


    exit_on_error:
        push rbp
        mov rbp, rsp

        call perror

        call __errno_location
        cmp dword [rax], 0
        je .skip2
            mov rdi, 1
            call exit
        .skip2 equ $

        pop rbp
        ret


    %define value rbp - 4
    handle_request:
        push rbp
        mov rbp, rsp
        sub rsp, 16

        call parse_request

        leave
        ret

        lea rdi, [absolute_request_path]
        lea rsi, [current_working_directory]
        mov rdx, PATH_MAX
        call strncpy

        lea rdi, [absolute_request_path]
        mov rsi, qword [path]
        mov rdx, PATH_MAX - 1
        call strncat

        mov rdi, STDOUT_FILENO
        load_string `absolute request path: %s\n`
        lea rsi, [string]
        lea rdx, [absolute_request_path]
        call dprintf

        lea rdi, [absolute_request_path]
        mov rsi, F_OK
        call access
        mov dword [value], eax

        call __errno_location
        mov dword [rax], 0

        cmp dword [value], 0
        jne .end

        lea rdi, [response_body]
        mov rsi, 0
        mov rdx, RESPONSE_BODY_SIZE
        call memset

        lea rdi, [absolute_request_path]
        call is_directory

        cmp rax, 1
        je .L1

        call serve_file

        jmp .L2

        .L1:
            call serve_directory

        .L2:
            mov rdi, STDOUT_FILENO
            load_string `%s\n`
            lea rsi, [string]
            lea rdx, [response_body]
            call dprintf

            lea rdi, [response_body]
            call strlen

            mov edi, dword [client_fd]
            lea rsi, [response_body]
            mov rdx, rax
            mov rcx, 0
            call send

            load_string `client send`
            lea rdi, [string]
            call exit_on_error

        .end:
            leave
            ret


    %define saveptr rbp - 8
    parse_request:
        push rbp
        mov rbp, rsp
        sub rsp, 16

        lea rdi, [buffer]
        load_string " "
        lea rsi, [string]
        lea rdx, [saveptr]
        call strtok_r

        mov qword [method], rax

        mov rdi, STDOUT_FILENO
        load_string `method: %s\n`
        lea rsi, [string]
        mov rdx, rax
        call dprintf

        mov rdi, NULL
        load_string " "
        lea rsi, [string]
        lea rdx, [saveptr]
        call strtok_r

        mov qword [path], rax

        mov rdi, STDOUT_FILENO
        load_string `path: %s\n`
        lea rsi, [string]
        mov rdx, rax
        call dprintf

        leave
        ret


    %define file_fd rbp - 4
    serve_file:
        push rbp
        mov rbp, rsp
        sub rsp, 16

        lea rdi, [absolute_request_path]
        mov rsi, O_RDONLY
        call open
        mov dword [file_fd], eax

        load_string `file open`
        lea rdi, [string]
        call exit_on_error

        mov edi, dword [file_fd]
        lea rsi, [response_body]
        mov rdx, RESPONSE_BODY_SIZE
        call read

        load_string `file read`
        lea rdi, [string]
        call exit_on_error

        mov edi, dword [file_fd]
        call close

        load_string `file close`
        lea rdi, [string]
        call exit_on_error

        leave
        ret


    %define directory rbp - 8
    %define entry rbp - 16
    %define name rbp - 24
    %define fullname rbp - 32
    %define displayname rbp - 40
    serve_directory:
        push rbp
        mov rbp, rsp
        sub rsp, 48

        mov rdi, PATH_MAX
        call malloc
        mov qword [name], rax

        mov rdi, PATH_MAX
        call malloc
        mov qword [fullname], rax

        mov rdi, PATH_MAX
        call malloc
        mov qword [displayname], rax

        lea rdi, [response_body]
        lea rsi, [html_begin]
        mov rdx, qword [path]
        mov rcx, qword [path]
        call sprintf

        lea rdi, [absolute_request_path]
        call opendir

        mov qword [directory], rax

        jmp .L2

        .L1:
            mov qword [entry], rax

            mov rdi, qword [name]
            mov rsi, qword [entry]
            add rsi, 19
            mov rdx, PATH_MAX
            call strncpy

            mov rdi, qword [fullname]
            lea rsi, [absolute_request_path]
            mov rdx, PATH_MAX
            call strncpy

            mov rdi, qword [fullname]
            call strlen

            mov rsi, qword [fullname]
            cmp byte [rsi + rax - 1], '/'
            je .skip3
                mov rdi, qword [fullname]
                load_string `/`
                lea rsi, [string]
                mov rdx, PATH_MAX
                call strncat
            .skip3 equ $

            mov rdi, qword [fullname]
            mov rsi, qword [name]
            mov rdx, PATH_MAX
            call strncat

            mov rdi, qword [displayname]
            mov rsi, qword [name]
            mov rdx, PATH_MAX
            call strncpy

            mov rdi, qword [fullname]
            call is_directory

            cmp rax, 1
            jne .skip4
                mov rdi, qword [displayname]
                load_string `/`
                lea rsi, [string]
                mov rdx, PATH_MAX
                call strncat
            .skip4 equ $

            lea rdi, [buffer]
            load_string `\t\t\t<li><a href="%s">%s</a></li>\n`
            lea rsi, [string]
            mov rdx, qword [displayname]
            mov rcx, qword [displayname]
            call sprintf

            lea rdi, [response_body]
            lea rsi, [buffer]
            mov rdx, RESPONSE_BODY_SIZE - 1
            call strncat

        .L2:
            mov rdi, qword [directory]
            call readdir

            cmp rax, NULL
            jne .L1

        mov rdi, qword [directory]
        call closedir

        lea rdi, [response_body]
        lea rsi, [html_end]
        mov rdx, RESPONSE_BODY_SIZE - 1
        call strncat

        mov rdi, qword [name]
        call free

        mov rdi, qword [fullname]
        call free

        mov rdi, qword [displayname]
        call free

        leave
        ret


    %define statbuf rbp - 256
    is_directory:
        push rbp
        mov rbp, rsp
        sub rsp, 256

        lea rsi, [statbuf]
        call stat

        load_string `stat`
        lea rdi, [string]
        call exit_on_error

        mov r8d, dword [statbuf + 24]
        and r8, 0xF000
        xor r8, 0x4000
        test r8, r8
        setnz al
        movzx rax, al
        not rax
        and rax, 1

        leave
        ret


section .rodata
    html_begin db `<html>\n\t<head>\n\t\t<title>%s</title>\n\t</head>\n\t<body>\n\t\t<ul>\n`, 0
    html_end db `\t\t</ul>\n\t</body>\n</html>`, 0


section .data


section .bss
    string resb 128
    current_working_directory resb PATH_MAX
    absolute_request_path resb PATH_MAX

    buffer resb BUFFER_SIZE
    response_body resb RESPONSE_BODY_SIZE

    method resq 1
    path resq 1

    server_fd resd 1
    server_addr resb 16

    client_fd resd 1
    client_addr resb 16
    client_len resd 1