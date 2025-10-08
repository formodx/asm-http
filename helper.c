#include <fcntl.h>
#include <limits.h>
#include <netinet/in.h>
#include <stdio.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>


int main(){
    FILE *file = fopen("constants.asm", "w");

    fprintf(file, "AF_INET equ %d\n", AF_INET);
    fprintf(file, "F_OK equ %d\n", F_OK);
    fprintf(file, "IPPROTO_IP equ %d\n", IPPROTO_IP);
    fprintf(file, "NULL equ 0\n");
    fprintf(file, "O_RDONLY equ %d\n", O_RDONLY);
    fprintf(file, "PATH_MAX equ %d\n", PATH_MAX);
    fprintf(file, "SOCK_STREAM equ %d\n", SOCK_STREAM);
    fprintf(file, "SOL_SOCKET equ %d\n", SOL_SOCKET);
    fprintf(file, "SO_REUSEADDR equ %d\n", SO_REUSEADDR);
    fprintf(file, "STDERR_FILENO equ %d\n", STDERR_FILENO);
    fprintf(file, "STDIN_FILENO equ %d\n", STDIN_FILENO);
    fprintf(file, "STDOUT_FILENO equ %d\n", STDOUT_FILENO);

    fclose(file);

    return 0;
}