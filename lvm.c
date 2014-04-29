#include <sys/socket.h>
#include <netinet/in.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>
#include <string.h>
#include <sys/times.h> 
#include <sys/select.h>
#include <sys/types.h>
#include <string.h>
#include <signal.h>

struct ProcessInfo{
	FILE *stream; /// Pointer to the duplex pipe stream
	pid_t pid; /// Process ID of the command
};

/*creat a pipe between this process and the process created by "command"*/
struct ProcessInfo* dpopen(char *const command[])
{
	int fd[2];
	pid_t pid;
	FILE *stream;
	struct ProcessInfo *pi;
	socketpair(AF_UNIX, SOCK_STREAM, 0, fd);	//creat pipe
	if ( (pid = fork()) == 0) { //child process
		close(fd[0]);	// close parent end
		dup2(fd[1], STDOUT_FILENO); // duplicate child end to standard ouput
		dup2(fd[1], STDIN_FILENO);	// duplicate child end to standard input
		close(fd[1]);	// close duplicated reading pipe.
		execvp(command[0],command);/* execute command using exec */
	} else {	// parent process
		close(fd[1]);	// close child end
		stream= fdopen(fd[0], "r+");
		pi = (struct ProcessInfo*)malloc(sizeof(struct ProcessInfo));
		pi->stream = stream;
		/* Successfully return here */
		pi->pid = pid;
		return pi;
		}
}

int lastpid;
void killp(int sig)
{
	if(lastpid != 0)
		kill(lastpid, sig);
	lastpid = 0;
}

int main()
{
	struct ProcessInfo *vm[128];
	FILE *vms;
	char *const cmd[] = {"vm", "-n", "bash", "-m", NULL};
	char buf[1024], inbuf[2048] = "vm -p \0", outbuf[1024], c, vmn_c[5],hosti[20]="host-vm\0", vmi[20]="eth0-vm\0";
	int i, cmdlen, n, vn, vmn, nextip=1;
	fd_set fds; 
	struct timeval timeout={0,0};

	lastpid = 0;
	char *tail = ";printf \"\\177\\n\"\n";
	printf("How many virtual machine you want to create(1~255):");
	scanf("%d", &vmn);
	scanf("%c",&c);
	/*Create a links between bridge host and vms*/	
	for(i = 0; i <= vmn - 1; ++i)
	{
		vm[i] = dpopen(cmd);
	
		sprintf(vmn_c, "%d", i);
		hosti[7]= '\0';
		vmi[7]= '\0';
		strcat(hosti, vmn_c);
		strcat(vmi, vmn_c);
		sprintf(buf, "ip link add name %s type veth peer name %s", hosti, vmi);
		system(buf);
		sprintf(buf, "sudo ip link set %s netns %d\n", vmi, vm[i]->pid);
		system(buf);
		sprintf(buf,"ifconfig %s up\n", vmi);
		fwrite(buf, strlen(buf)+1, 1, vm[i]->stream);
		sprintf(buf,"ifconfig %s 192.168.38.%d\n", vmi,nextip);
		fwrite(buf, strlen(buf)+1, 1, vm[i]->stream);
		++nextip;
		sprintf(buf,"ifconfig lo up\n");
		fwrite(buf, strlen(buf)+1, 1, vm[i]->stream);
	}

	signal(SIGINT,killp);
	
	/*CLI*/
	while(1)
	{
		printf(">>>");
		scanf("%c",&c);
		for(i=0; i<=1023 && c != '\n'; i++)
		{
			buf[i] = c;
			scanf("%c",&c);
		}
		buf[i] = '\0';
		cmdlen = i+1;
		if(buf[0] == 'v' && buf[1] == 'm')
		{
			for(i=2; buf[i] >= '0' && buf[i] <='9' && i <= cmdlen-1 ; ++i)
			{
				vmn_c[i-2] = buf[i];
			}
			if(buf[i] == ' ' || buf[i] == '\0')
			{
				vmn_c[i-2] = buf[i];
				n = atoi(vmn_c);
				if(n <= vmn-1)
				{
					vms = vm[n]->stream;
				}
				else
				{
					printf("ERROR: vm%d is not exist!\n", n);
					continue;
				}				
			}
			else
			{
				printf("ERROR: Unknown virtual machine!\n");
				continue;
			}
			inbuf[30] = '\0';
			strcat(inbuf,&buf[i]);
			strcat(inbuf, tail);
			fwrite(inbuf, strlen(inbuf)+1, 1, vms);
			select((int)vms+1, &fds, &fds, NULL, &timeout);
			
			fgets(outbuf, 1024, vms);
			for(i = 0; outbuf[0] != '\177'; ++i)
			{
				if(outbuf[0] == '\1')
				{
					lastpid = atoi(&outbuf[1]);
				}
				else
					printf("%s", outbuf);
				fgets(outbuf, 1024, vms);
			}
		}
		else if(!strcmp(buf,"exit\0"))
		{
			return;
		}
		else if(!strcmp(buf,"\0"))
		{
			continue;
		}
		else
			printf("ERROR: Unidentifiable command!\n");
	}
	return 0;
}
