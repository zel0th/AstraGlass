// AstraGlass bridge. Copyright 2026 AstraGlass contributors.
// SPDX-License-Identifier: AGPL-3.0-or-later
// Astrolog remains unchanged in Upstream; this entry point only serializes
// the positions and aspect grid computed by its own calculation routines.
#include "astrolog.h"
#include <cstring>

int AstrologMain(int argc, char **argv);

int main(int argc, char **argv) {
  // The host supplies a controlled resource working directory. Astrolog's
  // legacy 255-byte ephemeris path buffer concatenates argv[0] repeatedly for
  // each relative -Yi directory; app paths with spaces can exceed that buffer.
  // Use the resource directory and ASTROLOG path, never the app's long path.
  argv[0] = (char *)"astrolog";
  if (argc < 2 || strcmp(argv[1], "--json") != 0)
    return AstrologMain(argc, argv);
  InitProgram();
  is.szProgName = argv[0];
  FProcessSwitchFile(DEFAULT_INFOFILE, NULL);
  ciTran = ciHexa = ciFive = ciFour = ciThre = ciTwin = ciMain = ciCore;
  if (!FProcessSwitches(argc - 1, argv + 1) || !is.fHaveInfo)
    return 2;
  us.fAnsiColor = us.fAnsiChar = fFalse;
  for (int i = cuspLo; i <= cObj; ++i) {
    if ((!us.fCusp && FBetween(i, cuspLo, cuspHi)) ||
        (!us.fUranian && FBetween(i, uranLo, uranHi)) ||
        (!us.fDwarf && FBetween(i, dwarfLo, dwarfHi)) ||
        (!us.fMoons && FBetween(i, moonsLo, moonsHi)) ||
        (!us.fCOB && FBetween(i, cobLo, cobHi)) ||
        (!us.fStar && FBetween(i, starLo, starHi)))
      ignore[i] = ignore2[i] = fTrue;
  }
  byte previousIgnore[objMax];
  memcpy(previousIgnore, ignore, sizeof(previousIgnore));
  ciMain = ciCore;
  if (us.nRel) CastRelation(); else CastChart(1);
  if (!FCreateGrid(fFalse)) return 3;
  printf("{\"engine\":\"Astrolog 8.00\",\"julianDay\":%.10f,\"positions\":[", JulianDayFromTime(is.T));
  bool comma = false;
  for (int i = 0; i <= is.nObj; ++i) {
    if (FIgnore(i)) continue;
    if (comma) printf(","); comma = true;
    printf("{\"id\":%d,\"longitude\":%.10f,\"latitude\":%.10f,\"speed\":%.10f,\"house\":%d}",
      i, planet[i], planetalt[i], ret[i], inhouse[i]);
  }
  printf("],\"houseCusps\":[");
  for (int i = 1; i <= 12; ++i) printf("%s%.10f", i > 1 ? "," : "", chouse[i]);
  printf("],\"aspects\":["); comma = false;
  for (int y = 0; y <= is.nObj; ++y) if (!FIgnore(y))
    for (int x = 0; x < y; ++x) if (!FIgnore(x) && grid->n[x][y]) {
      if (comma) printf(","); comma = true;
      int a = grid->n[x][y];
      printf("{\"first\":%d,\"second\":%d,\"kind\":%d,\"angle\":%.8f,\"orb\":%.8f}",
        x, y, a, rAspAngle[a], grid->v[x][y]);
    }
  printf("],\"unavailableObjects\":["); comma = false;
  for (int i = 0; i <= is.nObj; ++i) if (!previousIgnore[i] && ignore[i]) {
    if (comma) printf(","); comma = true; printf("%d", i);
  }
  printf("]}\n");
  FinalizeProgram(fFalse);
  return 0;
}
