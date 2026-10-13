# Native reader fixtures

These synthetic 32×32 images were generated for this repository; no third-party
photos are included. The opaque reference color is RGB (64, 128, 192).

- `reference.png`: original reference.
- `reference.webp`: lossless WebP made with Pillow.
- `alpha.webp`: same color, alpha 128, lossless WebP made with Pillow.
- `reference.avif`: AV1 still image made from the PNG using:
  `ffmpeg -i reference.png -frames:v 1 -c:v libaom-av1 -still-picture 1 -crf 0 -pix_fmt yuv444p reference.avif`

The test allows a four-code-value tolerance for YUV/RGB rounding. RVIO's alpha
output uses premultiplied RGB, checked as (32, 64, 96, 128).
