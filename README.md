![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Nyan Cat player for Tiny Tapeout

Plays the Nyan Cat loop on a piezo buzzer from a 1x1 tile at 1.24 MHz.

- [Read the documentation for project](docs/info.md)

## What is Tiny Tapeout?

Tiny Tapeout is an educational project that aims to make it easier and cheaper than ever to get your digital and analog designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.

## Development

```sh
python3 -m venv .venv && source .venv/bin/activate
pip install -r test/requirements.txt

python3 model/nyan.py report            # pitch table and error in cents
python3 model/nyan.py gen               # regenerate src/nyan_tables.v after editing the song
python3 model/nyan.py wav out/nyan_model.wav   # listen to the reference model

cd test
make -B                                 # cocotb tests (whole song, octaves, pause)
make wav                                # simulate the RTL in real time -> out/nyan_rtl.wav (~1 min)
aplay ../out/nyan_rtl.wav
```

The song lives in `model/nyan.py`; `src/nyan_tables.v` is generated from it and the tests check the
hardware against it.

## Enable GitHub actions to build the results page

- [Enabling GitHub Pages](https://tinytapeout.com/faq/#my-github-action-is-failing-on-the-pages-part)

## Resources

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
- [Join the community](https://tinytapeout.com/discord)
- [Build your design locally](https://www.tinytapeout.com/guides/local-hardening/)

## What next?

- [Submit your design to the next shuttle](https://app.tinytapeout.com/).
- Edit [this README](README.md) and explain your design, how it works, and how to test it.
- Share your project on your social network of choice:
  - LinkedIn [#tinytapeout](https://www.linkedin.com/search/results/content/?keywords=%23tinytapeout) [@TinyTapeout](https://www.linkedin.com/company/100708654/)
  - Mastodon [#tinytapeout](https://chaos.social/tags/tinytapeout) [@matthewvenn](https://chaos.social/@matthewvenn)
  - X (formerly Twitter) [#tinytapeout](https://twitter.com/hashtag/tinytapeout) [@tinytapeout](https://twitter.com/tinytapeout)
  - Bluesky [@tinytapeout.com](https://bsky.app/profile/tinytapeout.com)
