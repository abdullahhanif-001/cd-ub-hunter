#include <stdio.h>
#include <stdlib.h>

/* Unsequenced side effects — CompDiff EvalOrder class (real bug class from paper).
 * gcc vs clang historically disagree on argument evaluation order. */

static int post_inc(int *value) {
  return (*value)++;
}

int main(int argc, char **argv) {
  FILE *in = stdin;
  if (argc >= 2) {
    in = fopen(argv[1], "rb");
    if (!in) {
      return 2;
    }
  }
  int base = 0;
  if (fscanf(in, "%d", &base) != 1) {
    if (in != stdin) {
      fclose(in);
    }
    return 2;
  }
  if (in != stdin) {
    fclose(in);
  }
  int i = base;
  /* Argument evaluation order is unspecified — preserves gcc vs clang disagreement. */
  printf("R %d %d %d\n", post_inc(&i), post_inc(&i), post_inc(&i));
  return 0;
}
