#include <stdio.h>
#include <stdlib.h>

/* Unsequenced side effects — CompDiff EvalOrder class (real bug class from paper).
 * gcc vs clang historically disagree on argument evaluation order. */

int main(int argc, char **argv) {
  FILE *in = stdin;
  if (argc >= 2) {
    in = fopen(argv[1], "rb");
    if (!in) return 2;
  }
  int base = 0;
  if (fscanf(in, "%d", &base) != 1) {
    if (in != stdin) fclose(in);
    return 2;
  }
  if (in != stdin) fclose(in);
  int i = base;
  printf("R %d %d %d\n", i++, i++, i++);
  return 0;
}
