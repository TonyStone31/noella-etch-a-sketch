# PDF export

Uses FPC's `fcl-pdf` (`fpPDF`), already installed with our Linux and Windows
compiler units. No OPM package, converter, DLL or shared PDF library is needed.
Font subsetting and compression also use FPC's Pascal implementation.

The application and our PDF integration remain MIT. FPC's modified LGPL
explicitly permits linking independent modules and distributing the executable
under their chosen terms, including commercial distribution. FPC library changes
remain under the library's terms; the library is used unmodified here.
See [the linking exception](help/licenses/FPC-linking-exception.txt) and
[the library license](help/licenses/FPC-COPYING.txt). Library source:
https://gitlab.com/freepascal.org/fpc/source/-/tree/main/packages/fcl-pdf
FPC licensing FAQ: https://www.freepascal.org/faq.html

Paper dimensions: https://support.hp.com/in-en/document/bpq04022

The selected scale is independent of screen zoom. The camera's center is kept,
with paper millimeters per world unit computed from the chosen scale (world
units are feet in imperial drawings, meters in metric drawings). Geometry is
projected at a fixed 96 units per paper inch and converted directly to PDF
coordinates. This is a coordinate convention, not raster resolution: there is
no drawing bitmap. The scale bar uses the same world-to-paper conversion.
The sheet has 10 mm margins and a 15 mm footer.

`TWorkDoc.WriteVectors` is shared by SVG and PDF. `uVector` defines the primitive
writer and SVG implementation; `uPdf` implements PDF paths and text. Faces use
even-odd fills so holes remain open. Arcs use the same segment count as SVG,
including explicitly chosen polygon sides. Dimension overrides are preserved.
SVG now escapes plain notes as XML as well as dimension labels.

Both formats retain SVG's entity order and simple face fills. They do not run
the shaded renderer's hidden-line pass. The dialog preview remains a framing
view of that renderer, so shading and hidden edges may differ from output.

PDF text uses an embedded subset of system Arial on Windows or DejaVu Sans /
Liberation Sans on Linux. Files are read directly, without fontconfig calls.
A PDF standard Courier fallback needs no font file; that fallback has limited
character coverage. No font files are added to the application distribution.

Scope: one vector sheet, preset paper and scales, portrait/landscape, axes,
framing, and the existing filename/overwrite/remember-directory workflow.
Future work: custom sheets/scales/margins and tiled multi-sheet output.

Validation: `tests/run-pdf.sh` checks all sheet sizes and orientations, metric
and imperial printed lengths, zoom independence, holes, clipping, SVG labels,
and absence of image objects. `tests/run-drive.sh export-dialog` exercises the
real dialog. External PDF tools used for testing are not application dependencies.
