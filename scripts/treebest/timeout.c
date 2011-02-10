/*++
 * NAME
 *	timeout 1
 * SUMMARY
 *	run command with bounded time
 * SYNOPSIS
 *	\fBtimeout\fR [-\fIsignal\fR] \fItime\fR \fIcommand\fR ...
 * DESCRIPTION
 *	\fBtimeout\fR executes a command and imposes an elapsed time limit.
 *	The command is run in a separate POSIX process group so that the
 *	right thing happens with commands that spawn child processes.
 *
 *	Arguments:
 * .IP \fI-signal\fR
 *	Specify an optional signal to send to the controlled process.
 *	By default, \fBtimeout\fR sends SIGKILL, which cannot be caught
 *	or ignored.
 * .IP \fItime\fR
 *	The elapsed time limit after which the command is terminated.
 * .IP \fIcommand\fR
 *	The command to be executed.
 * DIAGNOSTICS
 *	The command exit status is the exit status of the command
 *	(status 1 in case of a usage error).
 * AUTHOR(S)
 *	Wietse Venema
 *	This program is part of SATAN.
 *--*/

/* System libraries. */

#include <sys/types.h>
#include <sys/wait.h>
#include <signal.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>

extern int optind;

/* Application-specific. */

#define perrorexit(s) { perror(s); exit(1); }

static int kill_signal = SIGKILL;
static char *progname;
static char *commandname;

static void usage()
{
	fprintf(stderr, "usage: %s [-signal] time command...\n", progname);
	exit(1);
}

static void terminate(int sig)
{
	signal(kill_signal, SIG_DFL);
	fprintf(stderr, "Timeout: aborting command ``%s'' with signal %d\n", commandname, kill_signal);
	kill(0, kill_signal);
}

int main(int argc, char *argv[])
{
	int     time_to_run = 0;
	pid_t   pid;
	pid_t   child_pid;
	int     status;

	progname = argv[0];

	/*
	 * Parse JCL.
	 */
	while (--argc && *++argv && **argv == '-')
		if ((kill_signal = atoi(*argv + 1)) <= 0)
	    	usage();

	if (argc < 2 || (time_to_run = atoi(argv[0])) <= 0)
		usage();

	commandname = argv[1];

	/*
	 * Run the command and its watchdog in a separate process group so that
	 * both can be killed off with one signal.
	 */
	setsid();
	switch (child_pid = fork()) {
		case -1:					/* error */
			perrorexit("timeout: fork");
		case 00:					/* run controlled command */
			execvp(argv[1], argv + 1);
			perrorexit(argv[1]);
		default:					/* become watchdog */
			(void) signal(SIGHUP, terminate);
			(void) signal(SIGINT, terminate);
			(void) signal(SIGQUIT, terminate);
			(void) signal(SIGTERM, terminate);
			(void) signal(SIGALRM, terminate);
			alarm(time_to_run);
			while ((pid = wait(&status)) != -1 && pid != child_pid)
	    		/* void */ ;
			return (pid == child_pid ? status : -1);
	}
	return 0;
}
