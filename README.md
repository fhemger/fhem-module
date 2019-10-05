# fhem-module

## tfrec

Uses [tfrec](https://github.com/baycom/tfrec) to receive temperature sensors.(see tfrec for supported sensors)
It uses the SubProcess Module to pipe the output from tfrec to fhem.
Data is then dispatched to the LaCrosse Module for further porcessing and device creation.
  
## wolf_ism8

Listens on port 12004 (default) for messages send from Wolf ISM8 Hardware Module.

Creates devices for each Wolf device.
e.g.
* wolf_Heizung_HG1
* wolf_Heizung_BM1
* wolf_Heizung_MM1
* wolf_Heizung_MM2

Write to the ISM8 are untested and disabled.

Possibility to request all datapoints.

Use at your own Risk

Tested devices:
 * BM-2
 * CGB-2
 * MM-2
