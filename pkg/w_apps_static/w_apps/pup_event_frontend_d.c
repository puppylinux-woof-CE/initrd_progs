/*
*
* path:
*	/usr/local/pup_event/pup_event_frontend_d
*
* compile:
*	gcc -o pup_event_frontend_d pup_event_frontend_d.c
*	strip pup_event_frontend_d
*
*/

#include <stdlib.h>        // getenv(), system()
#include <sys/types.h>
#include <unistd.h>        // getpid() access()
#include <string.h>        // strstr() etc..
#include <stdio.h>

int debug = 0;
char *app_name = NULL;
FILE *outf = NULL;
int PUPMODE = 5;

#define EVENTMANAGER "/etc/eventmanager"
int POWERTIMEOUT = 0;
int RAMSAVEINTERVAL = 0;

#define trace(...) { fprintf (outf, __VA_ARGS__); }

//=============================================================================

char *get_value(char *buf) {
	char *s = strchr(buf, '=');
	s++;
	if (*s == '\'' || *s == '"') s++;
	char *p = s;
	p = strchr(buf, '\'');
	if (p) p = 0;
	p = strchr(buf, '"');
	if (p) p = 0;
	return s;
}

void read_eventmanager(void) {
	FILE *fp;
	char buf[256];
	char *filename = EVENTMANAGER;
	fp = fopen(filename, "r");
	if (fp == NULL){
		if (debug) trace("Could not open file %s\n",filename);
		return;
	}
	while (fgets(buf, 256, fp) != NULL) {
		if (strstr(buf, "RAMSAVEINTERVAL=")) {
			RAMSAVEINTERVAL = strtol(get_value(buf), NULL, 10);
			continue;
		} else if (strstr(buf, "POWERTIMEOUT=")) {
			POWERTIMEOUT = strtol(get_value(buf), NULL, 10);
		}
	}
	fclose(fp);
	return;
}

//=======================================================================
//                        MAIN
//=======================================================================

int main(int argc, char **argv) {

	outf = stderr;

	app_name = strrchr(argv[0], '/');
	if (app_name) app_name++;
	if (argv[1]) {
		if (strcmp(argv[1], "-debug") == 0) debug = 1;
	}
	if (getenv("PUPEVENT_DEBUG"))    debug = 1;
	if (getenv("PUP_EVENT_DEBUG"))   debug = 1;

	fprintf(stderr, "%s: starting...\n", app_name);

	// ==
	int ret = system("/usr/local/pup_event/frontend_startup");
	if (ret != 0) {
		trace("%s: exited with code: %d\n", app_name, WEXITSTATUS(ret));
		trace("exiting...\n");
		return 9;
	}

	// ==
	ret = system("/usr/local/bin/pupmode");
	PUPMODE = WEXITSTATUS(ret);
	if (debug) trace("PUPMODE %d\n", PUPMODE);

	unlink("/tmp/services/pup_event_timeout");
	
	//========================================================

	int MINUTE=0;
	int SAVECNT = 0;
	int MOUSECNT = 0;
	char CURPOS1[20] = "";
	char CURPOS2[20] = "";

	while (1) {

		sleep(60);
		MINUTE += 1;
		read_eventmanager();

		if (PUPMODE == 13) {
			SAVECNT += 1;
			if ((RAMSAVEINTERVAL > 0) && (SAVECNT >= RAMSAVEINTERVAL)) {
				if (debug) trace("call save2flash\n");
				int ret = system("/usr/sbin/save2flash pup_event");
				if (ret == 0) {
					if (debug) trace("save2flash ok\n");
					SAVECNT = 0;
				}
			}
		}

		if (POWERTIMEOUT > 0) { //power-off computer after inactivity.
			MOUSECNT += 1;
			FILE *fc = popen("getcurpos", "r");
			if (fc) {
				fgets(CURPOS2, sizeof(CURPOS2), fc);
				CURPOS2[strlen(CURPOS2) - 1] = 0;
				pclose(fc);
				if (!*CURPOS1) {
					strncpy(CURPOS1, CURPOS2, sizeof(CURPOS1));
				}
				if (debug) trace("[%s] - [%s]\n", CURPOS1, CURPOS2);
				if (strcmp(CURPOS1, CURPOS2) != 0) {
					printf("cursor changed position\n");
					MOUSECNT = 0;
				}
				strncpy(CURPOS1, CURPOS2, sizeof(CURPOS1));
				if (MOUSECNT >= POWERTIMEOUT) {
					system("wmpoweroff");
				}
			}
		}
	}

	return 0;
}

/* EOF */
