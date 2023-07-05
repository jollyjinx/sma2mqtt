#include "select.h"

void SWIFT_FD_SET(int d, fd_set *set) {
    FD_SET(d, &(*set));
}
