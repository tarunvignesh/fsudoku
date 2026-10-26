"""Pin variable fonts to static weights and subset them to the glyphs used.

The app only ever shows printable ASCII, so shipping full families would be
most of a megabyte of glyphs nobody sees.
"""
import os
import pathlib
import subprocess

VENV = pathlib.Path(os.environ.get('FONTTOOLS_BIN', 'fontenv/bin'))
OUT = pathlib.Path(__file__).resolve().parent.parent / 'assets' / 'fonts'
OUT.mkdir(parents=True, exist_ok=True)

# family -> (source, extra axes to pin at a sensible optical size)
FONTS = {
    'SourceSerif4': ('SourceSerif4.ttf', {'opsz': 20}),
    'JetBrainsMono': ('JetBrainsMono.ttf', {}),
    'Inter': ('Inter.ttf', {'opsz': 20}),
}
WEIGHTS = {'Regular': 400, 'SemiBold': 600}
UNICODES = 'U+0020-007E'  # printable ASCII

total = 0
for family, (src, extra) in FONTS.items():
    for name, wght in WEIGHTS.items():
        pins = [f'wght={wght}'] + [f'{k}={v}' for k, v in extra.items()]
        tmp = pathlib.Path(f'tmp_{family}_{name}.ttf')
        subprocess.run(
            [str(VENV / 'fonttools'), 'varLib.instancer',
             f'fonts_raw/{src}', *pins, '-o', str(tmp)],
            check=True, capture_output=True,
        )
        dest = OUT / f'{family}-{name}.ttf'
        subprocess.run(
            [str(VENV / 'pyftsubset'), str(tmp),
             f'--unicodes={UNICODES}',
             f'--output-file={dest}',
             '--layout-features=kern,liga,tnum',
             '--no-hinting', '--desubroutinize',
             '--drop-tables+=DSIG'],
            check=True, capture_output=True,
        )
        tmp.unlink()
        size = dest.stat().st_size
        total += size
        before = pathlib.Path(f'fonts_raw/{src}').stat().st_size
        print(f'{dest.name:<28} {size/1024:7.1f} KB   (from {before/1024:,.0f} KB)')

print(f'\ntotal shipped: {total/1024:,.1f} KB')
