#ifndef VETPILOT_BRIDGE_H
#define VETPILOT_BRIDGE_H
char *vetpilot_dispatch(const char *request);
void vetpilot_free(char *response);
#endif
