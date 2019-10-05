package main;
use strict;
use warnings;

use DevIo;
use TcpServerUtils;

#
# TODO
#	- docu
#	- inputs range and steps (partly)
# 	- encode/decode datatypes from 10_KNX.pm	
#	- Zeitprogramme 1 2 3 only 1 active !!
#	- timer delete disconnected clients TEMPORARY && disconnected ?
#	- check client connection
# 	- dblogexclude .*\.(DPID|Unit)
#	- MM dblogvaluefn { if ($VALUE == -40) { $IGNORE=1; } }
#	- create devices only if stoerung off ?!
#	- optimize, simplify, cleanup
#
# TCP-Server on Port 12004 (Default)
# Receive ISM8 datagramms
#
# Create device per Module
#
# Uses DateTimePicker Widget
#
# Write disabled per default. !!!! Use at your own risk encode function untested !!!!
#
# Successfully testet writes:
#	- request response
#	- request all datapoints
#
# Successfully tested with:
#	BM-2
#	CGB-2
#	MM-2
#

# Wolf Geräte
my %wolf_DPT_Devices = ( 
	HG1 => "Heizgerät 1",
	HG2 => "Heizgerät 2",
	HG3 => "Heizgerät 3",
	HG4 => "Heizgerät 4",
	BM1 => "Systembedienmodul", # mit Direkter Heizkreis/Warmwasser
	BM2 => "Mischerkreis 1",
	BM3 => "Mischerkreis 2",
	BM4 => "Mischerkreis 3",
	KM1 => "Kaskadenmodul",
	MM1 => "Mischermodul 1",
	MM2 => "Mischermodul 2",
	MM3 => "Mischermodul 3",
	SM1 => "Solarmodul",
	CWL => "CWL Excellent",
	HG0 => "Heigerät(1) BWL-1-S",
	UNKNOWN => "Unknown Datapoints", # device for unknown datapoints
);

# Wolf Datapoints
my %wolf_DPID_Types = (
	# Heizgerät 1 TOB, CGB-2 oder MGK-2
	1 => { DPT => 'DPT_Switch', Name => "Störung", Device => "HG1",  State => "Störung:S, Betriebsart:B"},
	2 => { DPT => 'DPT_HVACContrMode', Name => "Betriebsart", Device => "HG1",  State => "Störung:S, Betriebsart:B"},
	3 => { DPT => 'DPT_Scaling', Name => "Modulationsgrad / Brennerleistung", Device => "HG1" },
	4 => { DPT => 'DPT_Value_Temp', Name => "Kesseltemperatur", Device => "HG1" },
	5 => { DPT => 'DPT_Value_Temp', Name => "Sammlertemperatur", Device => "HG1" },
	6 => { DPT => 'DPT_Value_Temp', Name => "Rücklauftemperatur", Device => "HG1" },
	7 => { DPT => 'DPT_Value_Temp', Name => "Warmwassertemperatur", Device => "HG1" },
	8 => { DPT => 'DPT_Value_Temp', Name => "Außentemperatur", Device => "HG1" },
	9 => { DPT => 'DPT_Switch', Name => "Status Brenner/Flamme", Device => "HG1" },
	10 => { DPT => 'DPT_Switch', Name => "Status Heizkreispumpe", Device => "HG1" },
	11 => { DPT => 'DPT_Switch', Name => "Status Speicherladepumpe", Device => "HG1" },
	12 => { DPT => 'DPT_OpenClose', Name => "Status 3-Wege-Umschaltventil", Device => "HG1" },
	13 => { DPT => 'DPT_Value_Pres', Name => "Anlagendruck", Device => "HG1" },
	# In Kaskade: Heizgerät(2) TOB, CGB-2 oder MGK-2
	14 => { DPT => 'DPT_Switch', Name => "Störung", Device => "HG2",  State => "Störung:S, Betriebsart:B"},
	15 => { DPT => 'DPT_HVACContrMode', Name => "Betriebsart", Device => "HG2",  State => "Störung:S, Betriebsart:B"},
	16 => { DPT => 'DPT_Scaling', Name => "Modulationsgrad / Brennerleistung", Device => "HG2" },
	17 => { DPT => 'DPT_Value_Temp', Name => "Kesseltemperatur", Device => "HG2" },
	18 => { DPT => 'DPT_Value_Temp', Name => "Sammlertemperatur", Device => "HG2" },
	19 => { DPT => 'DPT_Value_Temp', Name => "Rücklauftemperatur", Device => "HG2" },
	20 => { DPT => 'DPT_Value_Temp', Name => "Warmwassertemperatur", Device => "HG2" },
	21 => { DPT => 'DPT_Value_Temp', Name => "Außentemperatur", Device => "HG2" },
	22 => { DPT => 'DPT_Switch', Name => "Status Brenner/Flamme", Device => "HG2" },
	23 => { DPT => 'DPT_Switch', Name => "Status Heizkreispumpe", Device => "HG2" },
	24 => { DPT => 'DPT_Switch', Name => "Status Speicherladepumpe", Device => "HG2" },
	25 => { DPT => 'DPT_OpenClose', Name => "Status 3-Wege-Umschaltventil", Device => "HG2" },
	26 => { DPT => 'DPT_Value_Pres', Name => "Anlagendruck", Device => "HG2" },
	# In Kaskade: Heizgerät(3) TOB, CGB-2 oder MGK-2
	27 => { DPT => 'DPT_Switch', Name => "Störung", Device => "HG3",  State => "Störung:S, Betriebsart:B"},
	28 => { DPT => 'DPT_HVACContrMode', Name => "Betriebsart", Device => "HG3",  State => "Störung:S, Betriebsart:B"},
	29 => { DPT => 'DPT_Scaling', Name => "Modulationsgrad / Brennerleistung", Device => "HG3" },
	30 => { DPT => 'DPT_Value_Temp', Name => "Kesseltemperatur", Device => "HG3" },
	31 => { DPT => 'DPT_Value_Temp', Name => "Sammlertemperatur", Device => "HG3" },
	32 => { DPT => 'DPT_Value_Temp', Name => "Rücklauftemperatur", Device => "HG3" },
	33 => { DPT => 'DPT_Value_Temp', Name => "Warmwassertemperatur", Device => "HG3" },
	34 => { DPT => 'DPT_Value_Temp', Name => "Außentemperatur", Device => "HG3" },
	35 => { DPT => 'DPT_Switch', Name => "Status Brenner/Flamme", Device => "HG3" },
	36 => { DPT => 'DPT_Switch', Name => "Status Heizkreispumpe", Device => "HG3" },
	37 => { DPT => 'DPT_Switch', Name => "Status Speicherladepumpe", Device => "HG3" },
	38 => { DPT => 'DPT_OpenClose', Name => "Status 3-Wege-Umschaltventil", Device => "HG3" },
	39 => { DPT => 'DPT_Value_Pres', Name => "Anlagendruck", Device => "HG3" },
	# In Kaskade: Heizgerät(4) TOB, CGB-2 oder MGK-2
	40 => { DPT => 'DPT_Switch', Name => "Störung",  Device => "HG4", State => "Störung:S, Betriebsart:B"},
	41 => { DPT => 'DPT_HVACContrMode', Name => "Betriebsart", Device => "HG4",  State => "Störung:S, Betriebsart:B"},
	42 => { DPT => 'DPT_Scaling', Name => "Modulationsgrad / Brennerleistung", Device => "HG4" },
	43 => { DPT => 'DPT_Value_Temp', Name => "Kesseltemperatur", Device => "HG4" },
	44 => { DPT => 'DPT_Value_Temp', Name => "Sammlertemperatur", Device => "HG4" },
	45 => { DPT => 'DPT_Value_Temp', Name => "Rücklauftemperatur", Device => "HG4" },
	46 => { DPT => 'DPT_Value_Temp', Name => "Warmwassertemperatur", Device => "HG4" },
	47 => { DPT => 'DPT_Value_Temp', Name => "Außentemperatur", Device => "HG4" },
	48 => { DPT => 'DPT_Switch', Name => "Status Brenner/Flamme", Device => "HG4" },
	49 => { DPT => 'DPT_Switch', Name => "Status Heizkreispumpe", Device => "HG4" },
	50 => { DPT => 'DPT_Switch', Name => "Status Speicherladepumpe", Device => "HG4" },
	51 => { DPT => 'DPT_OpenClose', Name => "Status 3-Wege-Umschaltventil", Device => "HG4" },
	52 => { DPT => 'DPT_Value_Pres', Name => "Anlagendruck", Device => "HG4" },
	# Systembedienmodul
	53 => { DPT => 'DPT_Switch', Name => "Störung", Device => "BM1",  State => "Störung:S, 1x Warmwasseraufladung (global):WWL"},
	54 => { DPT => 'DPT_Value_Temp', Name => "Außentemperatur", Device => "BM1" },
	# Direkter Heizkreis + direktes Warmwasser
	55 => { DPT => 'DPT_Value_Temp', Name => "Raumtemperatur", Device => "BM1" },
	56 => { DPT => 'DPT_Value_Temp', Name => "Warmwassersolltemperatur", Device => "BM1", Write => 1, Range => [ 20, 80], Step => 1},
	57 => { DPT => 'DPT_HVACMode', Name => "Programmwahl Heizkreis", Device => "BM1", Write => 1, Range => [ 0, 3], Step => 1},
	58 => { DPT => 'DPT_DHWMode', Name => "Programmwahl Warmwasser", Device => "BM1", Write => 1, Range => [ 0,0, 2,2, 4,4]}, # 0, 2, 4
	59 => { DPT => 'DPT_Switch', Name => "Heizkreis Zeitprogramm 1", Device => "BM1", Write => 1, Range => [ 0, 1], Step => 1},
	60 => { DPT => 'DPT_Switch', Name => "Heizkreis Zeitprogramm 2", Device => "BM1", Write => 1, Range => [ 0, 1], Step => 1},
	61 => { DPT => 'DPT_Switch', Name => "Heizkreis Zeitprogramm 3", Device => "BM1", Write => 1, Range => [ 0, 1], Step => 1},
	62 => { DPT => 'DPT_Switch', Name => "Warmwasser Zeitprogramm 1", Device => "BM1", Write => 1, Range => [ 0, 1], Step => 1},
	63 => { DPT => 'DPT_Switch', Name => "Warmwasser Zeitprogramm 2", Device => "BM1", Write => 1, Range => [ 0, 1], Step => 1},
	64 => { DPT => 'DPT_Switch', Name => "Warmwasser Zeitprogramm 3", Device => "BM1", Write => 1, Range => [ 0, 1], Step => 1},
	65 => { DPT => 'DPT_Value_Tempd', Name => "Sollwertkorrektur", Device => "BM1", Write => 1, Range => [ -4, 4], Step => 0.5},
	66 => { DPT => 'DPT_Value_Tempd', Name => "Sparfaktor", Device => "BM1", Write => 1, Range => [ 0, 10], Step => 0.5},
	# Mischerkreis 1 + Warmwasser 1
	67 => { DPT => 'DPT_Switch', Name => "Störung", Device => "BM2",  State => "Störung:S"},
	68 => { DPT => 'DPT_Value_Temp', Name => "Raumtemperatur", Device => "BM2" },
	69 => { DPT => 'DPT_Value_Temp', Name => "Warmwassersolltemperatur", Device => "BM2", Write => 1, Range => [ 20, 80], Step => 1},
	70 => { DPT => 'DPT_HVACMode', Name => "Programmwahl Mischer", Device => "BM2", Write => 1, Range => [ 0, 3], Step => 1},
	71 => { DPT => 'DPT_DHWMode', Name => "Programmwahl Warmwasser", Device => "BM2", Write => 1, Range => [ 0,0, 2,2, 4,4]},
	72 => { DPT => 'DPT_Switch', Name => "Mischer Zeitprogramm 1", Device => "BM2", Write => 1, Range => [ 0, 1], Step => 1},
	73 => { DPT => 'DPT_Switch', Name => "Mischer Zeitprogramm 2", Device => "BM2", Write => 1, Range => [ 0, 1], Step => 1},
	74 => { DPT => 'DPT_Switch', Name => "Mischer Zeitprogramm 3", Device => "BM2", Write => 1, Range => [ 0, 1], Step => 1},
	75 => { DPT => 'DPT_Switch', Name => "Warmwasser Zeitprogramm 1", Device => "BM2", Write => 1, Range => [ 0, 1], Step => 1},
	76 => { DPT => 'DPT_Switch', Name => "Warmwasser Zeitprogramm 2", Device => "BM2", Write => 1, Range => [ 0, 1], Step => 1},
	77 => { DPT => 'DPT_Switch', Name => "Warmwasser Zeitprogramm 3", Device => "BM2", Write => 1, Range => [ 0, 1], Step => 1},
	78 => { DPT => 'DPT_Value_Tempd', Name => "Sollwertkorrektur", Device => "BM2", Write => 1, Range => [ -4, 4], Step => 0.5},
	79 => { DPT => 'DPT_Value_Tempd', Name => "Sparfaktor", Device => "BM2", Write => 1, Range => [ 0, 10], Step => 0.5},
	# Mischerkreis 2 + Warmwasser 2
	80 => { DPT => 'DPT_Switch', Name => "Störung", Device => "BM3",  State => "Störung:S"},
	81 => { DPT => 'DPT_Value_Temp', Name => "Raumtemperatur", Device => "BM3" },
	82 => { DPT => 'DPT_Value_Temp', Name => "Warmwassersolltemperatur", Device => "BM3", Write => 1, Range => [ 20, 80], Step => 1},
	83 => { DPT => 'DPT_HVACMode', Name => "Programmwahl Mischer", Device => "BM3", Write => 1, Range => [ 0, 3], Step => 1},
	84 => { DPT => 'DPT_DHWMode', Name => "Programmwahl Warmwasser", Device => "BM3", Write => 1, Range => [ 0,0, 2,2, 4,4]},
	85 => { DPT => 'DPT_Switch', Name => "Mischer Zeitprogramm 1", Device => "BM3", Write => 1, Range => [ 0, 1], Step => 1},
	86 => { DPT => 'DPT_Switch', Name => "Mischer Zeitprogramm 2", Device => "BM3", Write => 1, Range => [ 0, 1], Step => 1},
	87 => { DPT => 'DPT_Switch', Name => "Mischer Zeitprogramm 3", Device => "BM3", Write => 1, Range => [ 0, 1], Step => 1},
	88 => { DPT => 'DPT_Switch', Name => "Warmwasser Zeitprogramm 1", Device => "BM3", Write => 1, Range => [ 0, 1], Step => 1},
	89 => { DPT => 'DPT_Switch', Name => "Warmwasser Zeitprogramm 2", Device => "BM3", Write => 1, Range => [ 0, 1], Step => 1},
	90 => { DPT => 'DPT_Switch', Name => "Warmwasser Zeitprogramm 3", Device => "BM3", Write => 1, Range => [ 0, 1], Step => 1},
	91 => { DPT => 'DPT_Value_Tempd', Name => "Sollwertkorrektur", Device => "BM3", Write => 1, Range => [ -4, 4], Step => 0.5},
	92 => { DPT => 'DPT_Value_Tempd', Name => "Sparfaktor", Device => "BM3", Write => 1, Range => [ 0, 10], Step => 0.5},
	# Mischerkreis 3 + Warmwasser 3
	93 => { DPT => 'DPT_Switch', Name => "Störung", Device => "BM4",  State => "Störung:S"},
	94 => { DPT => 'DPT_Value_Temp', Name => "Raumtemperatur", Device => "BM4" },
	95 => { DPT => 'DPT_Value_Temp', Name => "Warmwassersolltemperatur", Device => "BM4", Write => 1, Range => [ 20, 80], Step => 1},
	96 => { DPT => 'DPT_HVACMode', Name => "Programmwahl Mischer", Device => "BM4", Write => 1, Range => [ 0, 3], Step => 1},
	97 => { DPT => 'DPT_DHWMode', Name => "Programmwahl Warmwasser", Device => "BM4", Write => 1, Range => [ 0,0, 2,2, 4,4]}, # 0,2,4
	98 => { DPT => 'DPT_Switch', Name => "Mischer Zeitprogramm 1", Device => "BM4", Write => 1, Range => [ 0, 1], Step => 1},
	99 => { DPT => 'DPT_Switch', Name => "Mischer Zeitprogramm 2", Device => "BM4", Write => 1, Range => [ 0, 1], Step => 1},
	100 => { DPT => 'DPT_Switch', Name => "Mischer Zeitprogramm 3", Device => "BM4", Write => 1, Range => [ 0, 1], Step => 1},
	101 => { DPT => 'DPT_Switch', Name => "Warmwasser Zeitprogramm 1", Device => "BM4", Write => 1, Range => [ 0, 1], Step => 1},
	102 => { DPT => 'DPT_Switch', Name => "Warmwasser Zeitprogramm 2", Device => "BM4", Write => 1, Range => [ 0, 1], Step => 1},
	103 => { DPT => 'DPT_Switch', Name => "Warmwasser Zeitprogramm 3", Device => "BM4", Write => 1, Range => [ 0, 1], Step => 1},
	104 => { DPT => 'DPT_Value_Tempd', Name => "Sollwertkorrektur", Device => "BM4", Write => 1, Range => [ -4, 4], Step => 0.5},
	105 => { DPT => 'DPT_Value_Tempd', Name => "Sparfaktor", Device => "BM4", Write => 1, Range => [ 0, 10], Step => 0.5},
	# Kaskadenmodul
	106 => { DPT => 'DPT_Switch', Name => "Störung", Device => "KM1",  State => "Störung:S"},
	107 => { DPT => 'DPT_Value_Temp', Name => "Sammlertemperatur", Device => "KM1" },
	108 => { DPT => 'DPT_Switch', Name => "Gesamtmodulationsgrad", Device => "KM1" },
	109 => { DPT => 'DPT_Value_Temp', Name => "Vorlauftemperatur Mischerkreis", Device => "KM1" },
	110 => { DPT => 'DPT_Switch', Name => "Status Mischerkreispumpe", Device => "KM1" },
	111 => { DPT => 'DPT_Enable', Name => "Status Ausgang A1", Device => "KM1" },
	112 => { DPT => 'DPT_Value_Temp', Name => "Eingang E1", Device => "KM1" },
	113 => { DPT => 'DPT_Value_Temp', Name => "Eingang E2", Device => "KM1" },
	# Mischermodul 1
	114 => { DPT => 'DPT_Switch', Name => "Störung", Device => "MM1",  State => "Störung:S"},
	115 => { DPT => 'DPT_Value_Temp', Name => "Warmwassertemperatur", Device => "MM1" },
	116 => { DPT => 'DPT_Value_Temp', Name => "Vorlauftemperatur Mischerkreis", Device => "MM1" },
	117 => { DPT => 'DPT_Switch', Name => "Status Mischerkreispumpe", Device => "MM1", },
	118 => { DPT => 'DPT_Enable', Name => "Status Ausgang A1", Device => "MM1", },
	119 => { DPT => 'DPT_Value_Temp', Name => "Eingang E1", Device => "MM1", },
	120 => { DPT => 'DPT_Value_Temp', Name => "Eingang E2", Device => "MM1", },
	# Mischermodul 2
	121 => { DPT => 'DPT_Switch', Name => "Störung", Device => "MM2",  State => "Störung:S"},
	122 => { DPT => 'DPT_Value_Temp', Name => "Warmwassertemperatur", Device => "MM2", },
	123 => { DPT => 'DPT_Value_Temp', Name => "Vorlauftemperatur Mischerkreis", Device => "MM2" },
	124 => { DPT => 'DPT_Switch', Name => "Status Mischerkreispumpe", Device => "MM2" },
	125 => { DPT => 'DPT_Enable', Name => "Status Ausgang A1", Device => "MM2" },
	126 => { DPT => 'DPT_Value_Temp', Name => "Eingang E1", Device => "MM2" },
	127 => { DPT => 'DPT_Value_Temp', Name => "Eingang E2", Device => "MM2" },
	# Mischermodul 3
	128 => { DPT => 'DPT_Switch', Name => "Störung", Device => "MM3",  State => "Störung:S"},
	129 => { DPT => 'DPT_Value_Temp', Name => "Warmwassertemperatur", Device => "MM3" },
	130 => { DPT => 'DPT_Value_Temp', Name => "Vorlauftemperatur Mischerkreis", Device => "MM3" },
	131 => { DPT => 'DPT_Switch', Name => "Status Mischerkreispumpe", Device => "MM3" },
	132 => { DPT => 'DPT_Enable', Name => "Status Ausgang A1", Device => "MM3" },
	133 => { DPT => 'DPT_Value_Temp', Name => "Eingang E1", Device => "MM3" },
	134 => { DPT => 'DPT_Value_Temp', Name => "Eingang E2", Device => "MM3" },
	# Solarmodul
	135 => { DPT => 'DPT_Switch', Name => "Störung", Device => "SM1",  State => "Störung:S"},
	136 => { DPT => 'DPT_Value_Temp', Name => "Warmwassertemperatur Solar 1", Device => "SM1" },
	137 => { DPT => 'DPT_Value_Temp', Name => "Temperatur Kollektor 1", Device => "SM1" },
	138 => { DPT => 'DPT_Value_Temp', Name => "Eingang E1", Device => "SM1" },
	139 => { DPT => 'DPT_Value_Volume_Flow', Name => "Eingang E2 (Durchfluss)", Device => "SM1" },
	140 => { DPT => 'DPT_Value_Temp', Name => "Eingang E3", Device => "SM1" },
	141 => { DPT => 'DPT_Switch', Name => "Status Solarkreispumpe SKP 1", Device => "SM1" },
	142 => { DPT => 'DPT_Enable', Name => "Status Ausgang A1", Device => "SM1" },
	143 => { DPT => 'DPT_Enable', Name => "Status Ausgang A2", Device => "SM1" },
	144 => { DPT => 'DPT_Enable', Name => "Status Ausgang A3", Device => "SM1" },
	145 => { DPT => 'DPT_Enable', Name => "Status Ausgang A4", Device => "SM1" },
	146 => { DPT => 'DPT_Value_Volume_Flow', Name => "Durchfluss", Device => "SM1" },
	147 => { DPT => 'DPT_Power', Name => "aktuelle Leistung", Device => "SM1" },
	# CWL Excellent
	148 => { DPT => 'DPT_Switch', Name => "Störung", Device => "CWL",  State => "Störung:S, Filterwarnung aktiv:FW"},
	149 => { DPT => 'DPT_HVACMode', Name => "Programm", Device => "CWL", Write => 1, Range => [ 0,0, 1,1, 3,3]}, # 0, 1, 3
	140 => { DPT => 'DPT_Switch', Name => "Zeitprogramm 1", Device => "CWL", Write => 1, Range => [ 0, 1], Step => 1},
	151 => { DPT => 'DPT_Switch', Name => "Zeitprogramm 2", Device => "CWL", Write => 1, Range => [ 0, 1], Step => 1},
	152 => { DPT => 'DPT_Switch', Name => "Zeitprogramm 3", Device => "CWL", Write => 1, Range => [ 0, 1], Step => 1},
	153 => { DPT => 'DPT_Switch', Name => "Zeitweise Intensivlüftung AN/AUS", Device => "CWL", Write => 1, Range => [ 0, 1], Step => 1},
	154 => { DPT => 'DPT_Date', Name => "Zeitweise Intensivlüftung Startdatum", Device => "CWL", Write => 1},
	155 => { DPT => 'DPT_Date', Name => "Zeitweise Intensivlüftung Enddatum", Device => "CWL", Write => 1},
	156 => { DPT => 'DPT_TimeOfDay', Name => "Zeitweise Intensivlüftung Startzeit", Device => "CWL", Write => 1},
	157 => { DPT => 'DPT_TimeOfDay', Name => "Zeitweise Intensivlüftung Endzeit", Device => "CWL", Write => 1},
	158 => { DPT => 'DPT_Switch', Name => "Zeitweise Feuchteschutz AN/AUS", Device => "CWL", Write => 1, Range => [ 0, 1], Step => 1},
	159 => { DPT => 'DPT_Date', Name => "Zeitweise Feuchteschutz Startdatum", Device => "CWL", Write => 1},
	150 => { DPT => 'DPT_Date', Name => "Zeitweise Feuchteschutz Enddatum", Device => "CWL", Write => 1},
	161 => { DPT => 'DPT_TimeOfDay', Name => "Zeitweise Feuchteschutz Startzeit", Device => "CWL", Write => 1},
	162 => { DPT => 'DPT_TimeOfDay', Name => "Zeitweise Feuchteschutz Endzeit", Device => "CWL", Write => 1},
	163 => { DPT => 'DPT_Scaling', Name => "Lüftungsstufe", Device => "CWL" },
	164 => { DPT => 'DPT_Value_Temp', Name => "Ablufttemperatur", Device => "CWL" },
	165 => { DPT => 'DPT_Value_Temp', Name => "Frischlufttemperatur", Device => "CWL" },
	166 => { DPT => 'DPT_FlowRate_m3_h', Name => "Luftdurchsatz Zuluft", Device => "CWL" },
	167 => { DPT => 'DPT_FlowRate_m3_h', Name => "Luftdurchsatz Abluft", Device => "CWL" },
	168 => { DPT => 'DPT_Bool', Name => "Bypass Initialisierung", Device => "CWL" },
	169 => { DPT => 'DPT_Bool', Name => "Bypass öffnet/offen", Device => "CWL" },
	160 => { DPT => 'DPT_Bool', Name => "Bypass schließt/geschlossen", Device => "CWL" },
	171 => { DPT => 'DPT_Bool', Name => "Bypass Fehler", Device => "CWL" },
	172 => { DPT => 'DPT_Bool', Name => "Frost Status: Initialisierung/Warte", Device => "CWL" },
	173 => { DPT => 'DPT_Bool', Name => "Frost Status: Kein Frost", Device => "CWL" },
	174 => { DPT => 'DPT_Bool', Name => "Frost Status: Vorwärmer", Device => "CWL" },
	175 => { DPT => 'DPT_Bool', Name => "Frost Status: Fehler/Unausgeglichen", Device => "CWL" },
	# Heizgerät(1) BWL-1-S
	176 => { DPT => 'DPT_Switch', Name => "Störung", Device => "HG0",  State => "Störung:S"},
	177 => { DPT => 'DPT_HVACContrMode', Name => "Betriebsart", Device => "HG0" },
	178 => { DPT => 'DPT_Scaling', Name => "Heizleistung", Device => "HG0" },
	179 => { DPT => 'DPT_Scaling', Name => "Kühlleistung", Device => "HG0" },
	180 => { DPT => 'DPT_Value_Temp', Name => "Kesseltemperatur", Device => "HG0" },
	181 => { DPT => 'DPT_Value_Temp', Name => "Sammlertemperatur", Device => "HG0" },
	182 => { DPT => 'DPT_Value_Temp', Name => "Rücklauftemperatur", Device => "HG0" },
	183 => { DPT => 'DPT_Value_Temp', Name => "Warmwassertemperatur", Device => "HG0" },
	184 => { DPT => 'DPT_Value_Temp', Name => "Außentemperatur", Device => "HG0" },
	185 => { DPT => 'DPT_Switch', Name => "Status Heizkreispumpe", Device => "HG0" },
	186 => { DPT => 'DPT_Switch', Name => "Status Zubringer-/Heizkreispumpe", Device => "HG0" },
	187 => { DPT => 'DPT_OpenClose', Name => "Status 3-Wege-Umschaltventil HZ/WW", Device => "HG0" },
	188 => { DPT => 'DPT_OpenClose', Name => "Status 3-Wege-Umschaltventil HZ/K", Device => "HG0" },
	189 => { DPT => 'DPT_Switch', Name => "Status E-Heizung", Device => "HG0" },
	190 => { DPT => 'DPT_Value_Pres', Name => "Anlagendruck", Device => "HG0" },
	191 => { DPT => 'DPT_Power', Name => "Leistungsaufnahme", Device => "HG0" },
	# CWL Excellent
	192 => { DPT => 'DPT_Switch', Name => "Filterwarnung aktiv", Device => "CWL",  State => "Störung:S, Filterwarnung aktiv:FW"},
	193 => { DPT => 'DPT_Switch', Name => "Filterwarnung zurücksetzen", Device => "CWL", Write => 1, Range => [ 0, 1], Step => 1},
	# Systembedienmodul
	194 => { DPT => 'DPT_Switch', Name => "1x Warmwasseraufladung (global)", Device => "BM1", Write => 1, Range => [ 0, 1], Step => 1, State => "Störung:S, 1x Warmwasseraufladung (global):WWL"},
	# Solarmodul
	195 => { DPT => 'DPT_ActiveEnergy', Name => "Tagesertrag", Device => "SM1" },
	196 => { DPT => 'DPT_ActiveEnergy_kWh', Name => "Gesamtertrag", Device => "SM1" },
	# Heizgerät 1 (CGB-2, MGK-2, TOB, BWL-1S)
	197 => { DPT => 'DPT_Value_Temp', Name => "Abgastemperatur", Device => "HG1" },
	198 => { DPT => 'DPT_Scaling', Name => "Leistungsvorgabe", Device => "HG1", Write => 1, Range => [ 0, 100], Step => 1},
	199 => { DPT => 'DPT_Value_Temp', Name => "Kesselsolltemperaturvorgabe", Device => "HG1", Write => 1, Range => [ 20, 80], Step => 1},
	# Heizgerät 2 (CGB-2, MGK-2, TOB)
	200 => { DPT => 'DPT_Value_Temp', Name => "Abgastemperatur", Device => "HG2" },
	201 => { DPT => 'DPT_Scaling', Name => "Leistungsvorgabe", Device => "HG2", Write => 1, Range => [ 0, 100], Step => 1},
	202 => { DPT => 'DPT_Value_Temp', Name => "Kesselsolltemperaturvorgabe", Device => "HG2", Write => 1, Range => [ 20, 80], Step => 1},
	# Heizgerät 3 (CGB-2, MGK-2, TOB)
	203 => { DPT => 'DPT_Value_Temp', Name => "Abgastemperatur", Device => "HG3" },
	204 => { DPT => 'DPT_Scaling', Name => "Leistungsvorgabe", Device => "HG3", Write => 1, Range => [ 0, 100], Step => 1},
	205 => { DPT => 'DPT_Value_Temp', Name => "Kesselsolltemperaturvorgabe", Device => "HG3", Write => 1, Range => [ 20, 80], Step => 1},
	# Heizgerät 4 (CGB-2, MGK-2, TOB)
	206 => { DPT => 'DPT_Value_Temp', Name => "Abgastemperatur", Device => "HG4" },
	207 => { DPT => 'DPT_Scaling', Name => "Leistungsvorgabe", Device => "HG4", Write => 1, Range => [ 0, 100], Step => 1},
	208 => { DPT => 'DPT_Value_Temp', Name => "Kesselsolltemperaturvorgabe", Device => "HG4", Write => 1, Range => [ 20, 80], Step => 1},
	# Kaskadenmodul
	209 => { DPT => 'DPT_Scaling', Name => "Gesamtmodulationsgradvorgabe", Device => "KM1", Write => 1, Range => [ 0, 100], Step => 1},
	210 => { DPT => 'DPT_Value_Temp', Name => "Sammlersolltemperaturvorgabe", Device => "KM1", Write => 1, Range => [ 20, 80], Step => 1},
	#TODO 251 -361 Unknown Datapoints
	# 355 ISM8 Firmware Version ?!
); # DPID_Types

# Wolf Datapointtypes
# datatyp -> PDT
my %wolf_DPT_Types = (
	# 1.001
	DPT_Switch => { 
		PDT => 'PDT_BINARY_INFORMATION',
		Translate => ['Off', 'On' ], 
	},
	# 1.002
	DPT_Bool => {
		PDT => 'PDT_BINARY_INFORMATION',
		Translate => [ 'False', 'True' ],
	},
	# 1.003
	DPT_Enable => {
		PDT => 'PDT_BINARY_INFORMATION',
		Translate => [ 'Disable', 'Enable' ],
	},
	# 1.009
	DPT_OpenClose => {
		PDT => 'PDT_BINARY_INFORMATION',
		Translate => [ 'Open', 'Close' ],
	},
	# 5.001
	DPT_Scaling => {
		PDT => 'PDT_SCALING',
		Unit => '%',
		Range => [ 0, 100],
	},
	# 9.001
	DPT_Value_Temp => {
		PDT => 'PDT_KNX_FLOAT',
		Unit => '°C',
		Range => [ -273, 670760],
		Resolution => 0.01,
	},
	# 9.002
	DPT_Value_Tempd => {
		PDT => 'PDT_KNX_FLOAT',
		Unit => 'K',
		Range => [ -670760, 670760],
		Resolution => 0.01,
	},
	# 9.006
	DPT_Value_Pres => {
		PDT => 'PDT_KNX_FLOAT',
		Unit => 'Pa',
		Range => [ 0, 670760],
		Resolution => 0.01,
	},	
	# 9.024
	DPT_Power => {
		PDT => 'PDT_KNX_FLOAT',
		Unit => 'kW',
		Range => [ -670760, 670760],
		Resolution => 0.01,
	},	
	# 9.025
	DPT_Value_Volume_Flow => {
		PDT => 'PDT_KNX_FLOAT',
		Unit => 'l/h',
		Range => [ -670760, 670760],
		Resolution => 0.01,
	},
	# 10.001
	DPT_TimeOfDay => {
		PDT => 'PDT_TIME',
		Unit => 'TIME',
		Units => {
			Day => '',
			Hour => 'h',
			Minutes => 'min',
			Seconds => 's',
		},
	},
	# 11.001
	DPT_Date => {
		PDT => 'PDT_DATE',
		Unit => 'DATE',
		Units => {
			Day => '',
			Month => '',
			Year => '',
		},
	},
	# 13.002
	DPT_FlowRate_m3_h => {
		PDT => 'PDT_LONG',
		Unit => 'm3/h',
		Range => [ -2147483648, 2147483647],
		Resolution => 0.0001,
	},
	# 13.010
	DPT_ActiveEnergy => {
		PDT => 'PDT_LONG',
		Unit => 'Wh',
		Range => [ -2147483648, 2147483647],
	},
	# 13.013
	DPT_ActiveEnergy_kWh => {
		PDT => 'PDT_LONG',
		Unit => 'kWh',
		Range => [ -2147483648, 2147483647],
	},
	# 20.102
	DPT_HVACMode => {
		PDT => 'PDT_ENUM8',
		Unit => 'HVAC',
		Range => [ 0, 4],
		Translate => [
			'Auto',
			'Comfort',
			'Standby',
			'Economy',
			'Building Protection',
		],
	},
	# 20.103
	DPT_DHWMode => {
		PDT => 'PDT_ENUM8',
		Unit => 'HWH',
		Range => [ 0, 4],
		Translate => [
			'Auto',
			'LegioProtect',
			'Normal',
			'Reduced',
			'Off/FrostProtect',
		],
	},
	# 20.105
	DPT_HVACContrMode => {
		PDT => 'PDT_ENUM8',
		Unit => 'HVAC',
		Range => [ 0, 17, 20,20], # 0-17, 20
		Translate => [
			'Auto', #0
			'Heat',
			'Morning Warmup',
			'Cool',
			'Night Purge',
			'Precool',
			'Off',
			'Test',
			'Emergency Heat',
			'Fan Only',
			'Free Cool', # 10
			'Ice',
			'Max Heating Mode',
			'Economic Heat/Cool Mode',
			'Dehumidification',
			'Calibration Mode',
			'Emergency Cool Mode',
			'Emergency Steam Mode',
			'reserved', # 18
			'reserved', # 19
			'NoDem', # 20
		],
	},
); # DPT_Types

# Wolf PDT Datatypes
my %wolf_PDT_Types = (
	# 1.xxx
	PDT_BINARY_INFORMATION => {
			Template => 'C',
			Encode => sub { return pack("C", ($_[1] & 0b00000001)); },	# value -> bytes
			Decode => sub { return (unpack("C", $_[1]) & 0b00000001); },				# bytes -> value
	},
	# 5.xxx
	PDT_SCALING => {
			Template => 'C',
			Encode => sub { return pack("C", int(($_[1]) * 255 / 100)); }, #0-100 -> 0-255
			Decode => sub { return int(unpack("C",$_[1]) * 100 / 255); }, #0-255 -> 0-100
	},
	# 9.xxx
	PDT_KNX_FLOAT => {
			Template => 'n',
			Encode => sub {
				my $name = $_[0];
				my $v = $_[1];
				
## from10_KNP.pm
##	        #2-Octet Float value
##	        elsif ($code eq "dpt9")
##	        {
##	                my $sign = ($value <0 ? 0x8000 : 0);
##	                my $exp  = 0;
##	                my $mant = 0;
##	
##	                $mant = int($value * 100.0);
##	                while (abs($mant) > 0x7FF) 
##	                {
##	                        $mant /= 2;
##	                        $exp++;
##	                }
##	                $numval = $sign | ($exp << 11) | ($mant & 0x07ff);
##	               
##	                #get hex representation
##	                $hexval = sprintf("00%.4x",$numval);
##	        }


				my $sign = 0;
				
				Log3 $name, 5, "$name Encode PDT_KNXFLOAT invalue: $v 0x".unpack("H*", pack("n",$v))." 0b".unpack("B*", pack("n",$v));
				
				$v *= 100; # resolution 0.01
				
				if($v < 0) {
					$sign = 0b10000000_00000000;
					$v *= -1;
				}
				
				my $mant = $v / 2;
				my $expo = 0;
				$expo = int(log($v) / log($mant)) if($v != 0);
				
				if($sign) {
					$mant = (~$mant + 1) & 0b00000111_11111111;
				}
				
				$expo <<= 11;
				
				my $ret = pack("n", $sign | $expo | $mant);
	
				Log3 $name, 5, "$name Encode: mant: ".unpack("B*", pack("n",$mant));
				Log3 $name, 5, "$name Encode: expo: ".unpack("B*", pack("n",$expo));
				Log3 $name, 5, "$name Encode: sign: ".unpack("B*", pack("n",$sign));
				Log3 $name, 5, "$name Encode:  ret: ".unpack("B*", $ret);
			
				return $ret; # bytes
			}, # Encode
			Decode => sub {
				my $name = $_[0];
				my $v = unpack("n", $_[1]);
				
## from 10_KNX.pm			
##				#2-Octet Float value
##	        elsif ($code eq "dpt9")
##	        {
##	                $numval = hex($value);
##	                my $sign = 1;
##	                $sign = -1 if(($numval & 0x8000) > 0);
##	                my $exp = ($numval & 0x7800) >> 11;
##	                my $mant = ($numval & 0x07FF);
##	                $mant = -(~($mant-1) & 0x07FF) if($sign == -1);
##	                $numval = (1 << $exp) * 0.01 * $mant;
##	
##	                $numval = KNX_limit ($hash, $numval, $gadName, "DECODE");
##	               
##	                $state = sprintf ("%.2f","$numval");
##	        }
				
				Log3 $name, 5, "$name Decode PDT_KNXFLOAT invalue: 0x".unpack("H*", $_[1])." 0b".unpack("B*", $_[1]);
				
				return undef if($v == 0x7FFF); #invalid data
				
				my $expo = ($v & 0b01111000_00000000) >> 11;
				my $mant = ($v & 0b00000111_11111111);
				my $sign = ($v & 0b10000000_00000000);
				if($sign) {
					# negativ
					$mant = ~($mant - 1) & 0b00000111_11111111;
				}
				
				Log3 $name, 5, "$name Decode: expo: $expo ".unpack("B*", pack("n",$expo));
				Log3 $name, 5, "$name Decode: mant: $mant ".unpack("B*", pack("n",$mant));
				
				my $ret = ($mant) << $expo;
				
				$ret *= -1 if ($sign);
				
				Log3 $name, 5, "$name Decode: ret: $ret ".unpack("B*", pack("n",$ret));
				
				return $ret * 0.01;
			}, # Decode
	},
	#10.xxx
	PDT_TIME => {
			Template => 'a3',
			Encode => sub {
				my $name = $_[0];
				my ($wday, $time) = split(/ /,$_[1]);
				my ($hour, $minutes, $seconds) = split(/:/, $time);

				my @wdays = ( "no Day", "Mo", "Di", "Mi", "Do", "Fr", "Sa", "So" );
				my $day = grep(/^\Q$wday\E$/, @wdays);
				
				my $third = (($day << 5) & 0b11100000) | ($hour & 0b00011111);
				my $second = ($minutes & 0b00111111);
				my $first = ($seconds & 0b00111111);
				
				my $ret = pack("C C C", $third, $second, $first);
				
				Log3 $name, 5, "$name Encode ".$_[1]." PDT_TIME Byte: ".unpack("B*",$ret)." 0x".unpack("H*",$ret);

				return $ret; # bytes

			}, # Encode
			Decode => sub {
				my $name = $_[0];
				my ($third, $second, $first) = unpack("C C C",$_[1]);
				
				my $day = ($third & 0b11100000) >> 5;
				my $hour = ($third & 0b00011111);
				my $minutes = ($second & 0b00111111);
				my $seconds = ($first & 0b00111111);
				
				my @wdays = ( "no Day", "Mo", "Di", "Mi", "Do", "Fr", "Sa", "So" );
				
				Log3 $name, 5, "$name Day: ".unpack("B*",chr($day));
				Log3 $name, 5, "$name Hour: ".unpack("B*",chr($hour));
				Log3 $name, 5, "$name Minutes: ".unpack("B*",chr($minutes));
				Log3 $name, 5, "$name Seconds: ".unpack("B*",chr($seconds));
				
				Log3 $name, 5, "$name Decode PDT_TIME: $day ".$wdays[$day]." $hour $minutes $seconds\n";
				
				return sprintf("%s %02i:%02i:%02i",$wdays[$day],$hour,$minutes,$seconds);
			}, # Decode
	},
	#11.xxx
	PDT_DATE => {
			Template => 'a3',
			Encode => sub { 
				my $name = $_[0];
				my ($day, $month, $year) = split(/./, $_[1]);
	
				my $third = ($day & 0b00011111);
				my $second = ($month & 0b00001111);
				my $first = ($year & 0b01111111);
				
				my $ret = pack("C C C", $third, $second, $first);
				
				Log3 $name, 5, "$name Encode ".$_[1]." PDT_DATE Byte: ".unpack("B*",$ret)." 0x".unpack("H*",$ret);
				
				return $ret; # bytes
			}, # Encode
			Decode => sub {
				my $name = $_[0];
				my ($third, $second, $first) = unpack("C C C", $_[1]);
	
				my $day = ($third & 0b00011111);
				my $month = ($second & 0b00001111);
				my $year = ($first & 0b01111111);
				
				Log3 $name, 5, "$name Day: ".unpack("B*",chr($day));
				Log3 $name, 5, "$name Month: ".unpack("B*",chr($month));
				Log3 $name, 5, "$name Year: ".unpack("B*",chr($year));
				Log3 $name, 5, "$name Decode PDT_DATE: $day $month $year";

				return sprintf("%02i.%02i.%04i",$day,$month,$year);
			}, #Decode
			Resolution => 1,
	},
	#13.xxx
	PDT_LONG => {
			Template => 'l',
			Encode => sub { return pack("l", $_[1]); }, # value -> bytes
			Decode => sub { return unpack("l", $_[1]); }, # bytes -> value
	},
	#20.xxx
	PDT_ENUM8 => {
			Template => 'C',
			Encode => sub { return pack("C", $_[1]); }, # value -> bytes
			Decode => sub { return unpack("C", $_[1]); }, # bytes -> value
	},
); # PDT_Type

################################################################################
#
#
#

sub wolf_ism8_Initialize($) {
    my ($hash) = @_;

    $hash->{DefFn}			= 'wolf_Define';
    $hash->{UndefFn}		= 'wolf_Undef';
    $hash->{SetFn}			= 'wolf_Set';
    $hash->{GetFn}			= 'wolf_Get';
    $hash->{AttrFn}			= 'wolf_Attr';
    $hash->{ReadFn}			= 'wolf_Read';
	#$hash->{WriteFn}			= 'wolf_Write';
	$hash->{ParseFn}		= 'wolf_Parse';
	$hash->{NotifyFn}		= 'wolf_Notify';

    $hash->{AttrList} = "LocalAddr LocalPort "
					."disable:1,0 disabledForIntervals "
					."writeallowed:true,false "
					."createunknowndatapoints:0,1 "
					.$readingFnAttributes;
}

sub wolf_Define($$) {
    my ($hash, $def) = @_;
    my @param = split('[ \t]+', $def, 4);
    
    if(int(@param) < 2) {
        return "too few parameters: define <name> wolf_ism8 <device> <alias>"; # device default "server"
    }
	
	my $name = $param[0];
    $hash->{NAME}  = $name;
	

	my $device = $param[2];
	if(!defined($device)) {
		# Server
		$device = "server";
	}
	
	my $alias = $param[3];
	
	if(defined($alias)) {
		$attr{$name}{alias} = $alias;
	}
		
	$hash->{Device} = $device;
	
	my $type = $hash->{TYPE};
	
	Log3 $name, 5, "$name Define Type: $type Device: $device";
	
	if($device eq "server") {
		$hash->{Clients} = "wolf_ism8";
		$hash->{MatchList} = { "1:wolf_ism8" => "^(\\S+\\s){3}"};
	
		$attr{$name}{LocalPort} = 12004;
		$attr{$name}{LocalAddr} = "global"; #"0.0.0.0";
		
		
		if($init_done) {
			wolf_InitServer($hash);
		} # else see NOTIFY INITIALIZED
		
		$hash->{InDatapoints} = "";
		
		return undef; 
	} 

	#
	# wolf Module
	
	AssignIoPort($hash);
	
	if(defined($hash->{IODev})) {
		my $iodev = $hash->{IODev}->{NAME};
		
		$attr{$name}{group} = $iodev;
		
		my $rval = ReadingsVal($name, ".associatedWith", '');
		if( $rval !~ /$iodev/ ) {
			chomp(my $nval = "$rval $iodev");
			my $rv = readingsSingleUpdate($hash, ".associatedWith", "$nval", 0);
			Log3 $name, 4, "$name Update Reading: \"$rv\"";
		}
	}
	$hash->{InDatapoints} = "";
	
	# populate inputs see set
	foreach my $dpid (keys (%wolf_DPID_Types)) {
		# all input datapoints of the device
		next if($wolf_DPID_Types{$dpid}->{Device} ne $device
				|| !defined($wolf_DPID_Types{$dpid}{Write})
				||	!$wolf_DPID_Types{$dpid}->{Write}
				);
		
		# generate set name
		my $setname = $wolf_DPID_Types{$dpid}{Name};
		chomp($setname);
		$setname = wolf_makeReadingName($setname);
		
		# set name to datapoint id
		$hash->{Inputs}{$setname} = $dpid;	

		# TODO args
		my $args = "";
		#if(ref($var) eq 'ARRAY'
		my @argslist = wolf_getDPTArgs($name, $dpid);
		
		if(@argslist) {
			$args = join(',', grep( s/ \d+$//, @argslist )); # arg list
		
			$args = ":$args" if($args);
			
			#$args = ":noArg" if($dpid == 194);
		}
		
		$hash->{InDatapoints} .= "$setname$args ";
	}
	
	#$hash->{InDatapoints} = join(' ', keys(%{ $hash->{Inputs} }));
	$hash->{STATE} = "initialized";

	$modules{$type}{defptr}{$name} = $hash;
	
	return undef;
	
} #Define

sub wolf_InitServer($) {
	my $hash = $_[0];
	my $name = $hash->{NAME};
	
	return if(IsDisabled($name));
	
	return if($hash->{Device} ne "server");
	
	# TCP
	my $localport = AttrVal($name, "LocalPort", undef);
	my $localaddr = AttrVal($name, "LocalAddr", undef);

	# close old if available
	if(defined($hash->{FD})) {
		Log3 $name, 3, "$name Closing Server Socket";
		TcpServer_Close($hash);
		
	}
	
	my $ret = TcpServer_Open($hash,$localport,$localaddr);
	if($ret) {
		Log3 $name, 1, "$name InitServer error $!";
		$hash->{"STATE"} = "failed";
		return $ret;
	}
	
	#$hash->{"Port"} = $localport;
	$hash->{"Address"} = $localaddr;
	$hash->{"STATE"} = "initialized";
	
    return $ret;
} # InitServer

sub wolf_Undef($$) {
    my ($hash, $arg) = @_;
	
	my $name = $hash->{NAME};
	
	if(defined($hash->{SERVERSOCKET}) || defined($hash->{CD})) {
		TcpServer_Close($hash);
		return if($hash->{Device} eq "server");			
	}
	
	my $sname = $hash->{SNAME};
	$sname = $name if(!defined($sname));
	
	if($hash->{Device} eq "client") {
		TcpServer_Close($hash);
		$defs{$sname}->{CONNECTS}--;
		delete($defs{$sname}->{lastclient}) if(defined($defs{$sname}->{lastclient}) && $defs{$sname}->{lastclient} eq $name);
		readingsSingleUpdate($hash, "state", "disconnected", 0);
		Log3($sname, 5, "$name -CLOSE Socket-");
		return;
	}
	
	my $type = $defs{$sname}->{TYPE};
	
	delete($modules{$type}{defptr}{$name});
	
	return;
 
} # Undef

sub wolf_Read($) {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $sname = $hash->{SNAME};
	
	return if(IsDisabled($sname));
	
	$sname = $name if(!defined($sname));
	
	return if(IsDisabled($name));
	
	Log3($sname, 5, "$name ---> Read <---");	
	
	wolf_tcp($hash);

} # Read
	
sub wolf_tcp($) {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	
	Log3 $name, 5, "$name ---> Tcp Read <---";
	
	if(!$hash->{SERVERSOCKET}) {
		my $sname = $hash->{SNAME};
		
		Log3 $sname, 5, "$name ---> Client Read <---";
		
		Log3 $sname, 5, "$name NAME: $name SNAME: $sname";
				
		my $len = 4096;
		my $buf;
		my $ret = sysread($hash->{CD}, $buf, $len); 
		
		if(!defined($ret) || (defined($ret) && $ret == 0)) {
		
			if(!defined($ret)) {
				Log3($sname, 1, "$name Connection error: $!");
			} else {
				# $ret == 0
				Log3 $sname, 5, "$name sysread: len: $ret bytes:".unpack('H*',$buf);
				Log3($sname, 5, "$name Connection done.");
			}
			
			#close
			use bytes;
			Log3($sname, 5, "$name Buffer Size: ".length($hash->{BUF})." BUF: ".unpack("H*",$hash->{BUF}));
			
			TcpServer_Close($hash);
			$defs{$sname}->{CONNECTS}--;
			delete($defs{$sname}->{lastclient}) if(defined($defs{$sname}->{lastclient}) && $defs{$sname}->{lastclient} eq $name);
			readingsSingleUpdate($hash, "state", "disconnected", 0);
			Log3($sname, 5, "$name -CLOSE Socket-");
			
			return;
		}
		
		Log3 $sname, 5, "$name sysread: len: $ret bytes:".unpack('H*',$buf);
		
		$hash->{BUF} .= $buf;
		
		Log3($sname, 5, "$sname Buffer after read: ".unpack('H*',$hash->{BUF}));
		
		# Debug
		if($hash->{BUF} =~ /exit/) {
			TcpServer_Close($hash);
			$defs{$sname}->{CONNECTS}--;
			delete($defs{$sname}->{lastclient}) if(defined($defs{$sname}->{lastclient}) && $defs{$sname}->{lastclient} eq $name);
			readingsSingleUpdate($hash, "state", "disconnected", 0);
			Log3($sname, 5, "$name -CLOSE Socket-");

			return;
		}
		
		# process and modify BUF !!
		wolf_getFrames($hash);
				
		return;
	}
	
	if($hash->{SERVERSOCKET}) {
		my $chash = TcpServer_Accept($hash, $hash->{TYPE});
		
		Log3($name, 5, "$name Tcp Accept ".$chash->{NAME});
		
		#return if(!$chash);
		# TODO on error ?
		
		#$chash->{Device} = "";
		$chash->{InDatapoints} = ""; # avoid PERL Warnings
		$chash->{Device} = "client"; # avoid PERL Warnings
		
		$hash->{lastclient} = $chash->{NAME};
		return;
	}
	
	Log3 $name, 1, "$name Exception";
	
	return undef;
} # Tcp

# find frames in $hash->{BUF}
# updates $hash->{BUF} !!
sub wolf_getFrames($) {
	my $hash = $_[0];
	my $name = $hash->{NAME};
	my $sname = $hash->{SNAME};
	
	if($hash->{BUF} !~ /..\xF0\x80/) {
		# not found \xF0\x80 clear buffer except 3 bytes
		my $ignore = length($hash->{BUF}) - 3; 
		return if($ignore > 0);
		$hash->{BUF} = unpack("x$ignore a*", $hash->{BUF});
		Log3 $sname, 5, "$name Buffer cleared except 3 bytes";
		return; #wait for more data
	}
	# xx xx F0 80 = Header Version ObjectServerReq (4 bytes)
	while($hash->{BUF} =~ /..\xF0\x80/) {
		
		if( $+[0] > 4) { # $-[0] - 2 ??
			# remove trailing bytes
			my $ignore = $+[0] - 4;
			
			return if($ignore < 0);
			
			Log3 $sname, 5, "$name remove trailing $ignore bytes from buffer";
			$hash->{BUF} = unpack("x$ignore a*", $hash->{BUF});	
			#check min buffer size
			return if(length($hash->{BUF})<20); # minimal size 21 bytes
		};
		
		Log3 $sname, 4, "$name Found ObjectServerReq 0xF080 at start:".$-[0]." end: ".$+[0];
		
		# start identifying frame and remove it from buffer
		
		my $BufferSize = length($hash->{BUF});
		Log3 $sname, 5, "$name getFrames Buffer Length: $BufferSize";
	
		# $HeaderSize = HeaderSize + Version + ServiceTypeId(2 byte) + FrameSize(2 byte) = 0x06 = 6 bytes
		# $ServiceTypeId = 0xF080 ObjectServerRequest 2 byte
		my ($HeaderSize, $Version, $ServiceTypeId, $FrameSize) = unpack("C C a2 n",$hash->{BUF});
		
		Log3 $sname, 5, "$name Buffer Length: ".length($hash->{BUF})." HeaderSize: $HeaderSize Version: $Version ServiceTypeId: ".unpack('H*',$ServiceTypeId)." FrameSize: $FrameSize"; # min FrameSize = 21
		
		Log3 $sname, 4, "$name HeaderSize not equal 0x06 !!" if($HeaderSize != 6);
	
		if($BufferSize < $FrameSize) {
			Log3 $sname, 1, "$sname getFrames BufferSize < FrameSize !!\n";
			last; # wait for more data -> BUF unchanged!!
		}

		my $ObjServerMsgSize = $FrameSize - $HeaderSize - 4; # FrameSize - HeaderSize(6) - ConHeaderSize(4)
		# $ConHeader = 0x04000000 (Structur Length(0x04) + 3 x Reserved (0x00)) 4 byte
		# $HeaderSize = 6 byte;
		
		my $ObjServerMsg;
		# shortens $hash->{BUF} !!!!
		# x$HeaderSize = ignore HeaderSize bytes
		# x4 = ignore 4 bytes (Connection Header)
		($ObjServerMsg, $hash->{BUF}) = unpack("x$HeaderSize x4 a$ObjServerMsgSize a*", $hash->{BUF});
		
		Log3 $sname, 5, "$name processing datapoints";
		wolf_doDatapoints($hash, $ObjServerMsg);
	}
} # getFrames

sub wolf_doDatapoints($$) {
	my $hash = $_[0];
	my $datapoints = $_[1];
	
	my $name = $hash->{NAME};
	my $sname = $hash->{SNAME};
	
	my $dpslength = length($datapoints);
	Log3 $sname, 4, "$name Datapoints Length: $dpslength parsing 0x".unpack('H*', $datapoints);
	
	# check min length ?!
	
	my ($MainService, $SubService, $StartDatapoint, $NumberOfDatapoints);
	($MainService, $SubService, $StartDatapoint, $NumberOfDatapoints, $datapoints) = unpack("C C n n a*", $datapoints);

	Log3 $sname, 5, "$sname MainService: ".sprintf('0x%02X',$MainService)." SubService: ".sprintf('0x%02X',$SubService); #." (".$SubServices{$SubService}.")";
	Log3 $sname, 5, "$sname StartDatapoint: $StartDatapoint NumberOfDatapoints: $NumberOfDatapoints DPslength: ".length($datapoints);
	
	if($SubService != 0X06) {
		Log3 $sname, 2, "$sname Unknown SubService ignoring, MainService: ".sprintf('0x%02X',$MainService)." SubService: ".sprintf('0x%02X',$SubService)." StartDatapoint: $StartDatapoint NumberOfDatapoints: $NumberOfDatapoints DPslength: ".length($datapoints);
		return;
	}

	# send response Frame
	Log3 $sname, 5, "$name sending response frame. StartDatapoint: $StartDatapoint";
	return if(!wolf_sendFrame($hash, 0x86, $StartDatapoint));
	
	# TODO detect repeated Messages CRC?
	
	while($datapoints) {

		last if(length($datapoints) < 5);
		
		# Dpid DPcmd DPlength DPvalue
		my ($DPid, $DPcmd, $DPlength, $DPvaluebytes);
		($DPid, $DPcmd, $DPlength, $datapoints)  = unpack("n C C a*", $datapoints);
		
		if(!defined($wolf_DPID_Types{$DPid})) {
			Log3 $sname, 1, "$sname Unknown Datapoint ID: $DPid $DPcmd $DPlength Datapoints: 0x".unpack("H*", $datapoints);
			
			# Debug attribute unknown see parseFns also
			next if(!AttrVal($sname, "createunknowndatapoints", 0));
		}
		
		# get bytes of DP length
		($DPvaluebytes, $datapoints) = unpack("a$DPlength a*", $datapoints);
		
		my $msg = "$DPid $DPcmd $DPlength $DPvaluebytes";
		my $logmsg = "$DPid $DPcmd $DPlength 0x".unpack("H*",$DPvaluebytes);
		
		Log3 $sname, 5, "$name Dispatch \"$logmsg\"";
		my @found = Dispatch($defs{$sname}, $msg); # addvals?
		
		my $fdev = $found[0][0];
		
		if(!defined($fdev)) {
			Log3 $sname, 4, "$sname Dispatch returns undef msg: $logmsg";
			#return;
		}
	}
	
} # doDatapoints

sub wolf_sendFrame($$;$$$$)
{
	my $hash = $_[0];
	my $SubService = $_[1];
	my $dpid = $_[2];
	my $dpvalue = $_[3];
	my $ErrorCode = $_[4] // 0;
	my $dry = $_[5] // 0;

	my $MainService = 0xF0;

	my $name = $hash->{NAME};
	my $sname = $hash->{SNAME};
	
	my $chash = $hash;
	
	#Find client
	if($hash->{Device} ne "client") {
		if($hash->{Device} eq "server") {
			$chash = $defs{$hash->{lastclient}} if(defined($hash->{lastclient})); # server
			$sname = $name;
		} else {
			$sname = $hash->{IODev}->{NAME};
			my $iodev = $defs{$sname};
			
			if(defined($iodev->{lastclient})) {
				$chash = $defs{$iodev->{lastclient}};
			} else {
				Log3 $sname, 1, "$name $sname TCPServer SendFrame No active Client found";
				return 0;
			}
		}
	}
	
	if(!defined($chash) || $chash->{Device} ne "client") {
			Log3 $sname, 1, "$name $sname TCPServer SendFrame Client device not found";
			return 0;
	}
	
	my $cname = $chash->{NAME};
	
	# sent positive response
	##	Error code Description
	##	0 No error
	##	1 Internal error
	##	2 No item found
	##	3 Buffer is too small
	##	4 Item is not writeable
	##	5 Service is not supported
	##	6 Bad service parameter
	##	7 Wrong datapoint ID
	##	8 Bad datapoint command
	##	9 Bad length of the datapoint value
	##	10 Message inconsistent 
	## StartDatapoint = Index of bad datapoint 
	
	my %SubServices = (
#		0x06 => 'SetDatapointValue.Req', # ISM Output
		0x86 => 'SetDatapointValue.Res', # Response to ISM Output
		0xC1 => 'DatapointValue.Ind', # ISM Input Indication
		0xD0 => 'request all datapoints' #
	);
	
	Log3 $sname, 4, "$cname TCPServer SendFrame SubService: ".sprintf("0x%02X", $SubService)." (".$SubServices{$SubService}.")";
	
	my $msg = ""; 
	my $NumberOfDatapoints = 0;
	
	my $datapoints = pack("C", $ErrorCode);
	
	# 0xC1
	if($SubService == 0xC1) {
		# $dpstate = 0x00; for first DP
		my $dpstate = 0;
		my $dplength = length($dpvalue);
		# DPID, DPstate, DPlength, DPvalue
		$datapoints = pack("n C C a*", $dpid, $dpstate, $dplength, $dpvalue);
		$NumberOfDatapoints = 1;
	}
	
	# 0x86 0xC1
	if($SubService != 0xD0) {
		#StartDatapoint, NumberOfDatapoints, $datapoints
		$msg = pack("n n a*", $dpid, $NumberOfDatapoints, $datapoints);
	}
	
	# MainService, SubService $msg
	my $objservermsg = pack("C C a*", $MainService, $SubService, $msg);
	
	my $size = length($objservermsg);
	
	# 0xd0
	$size = 6 if($SubService == 0xD0);
	
	# Headersize = 0x06, Version = 0x20, ObjServerreq = 0xF080, Headerlength (10) + objectservermsglength, ConHeader = 0x04000000
	my $header = pack("C C n n a4", 0x06, 0x20, 0xF080, 10 + $size, "\x04\x00\x00\x00");
	
	my $bytes = $header.$objservermsg;
	
	# Device = client
	my $retmsg = " -Dry run-";
	if(!$dry) {
		$retmsg = "";
		if(!TcpServer_WriteBlocking($chash, $bytes)) {
			Log3 $sname, 1, "$cname TCPServer SendFrame Error \"$!\" writing bytes 0x".unpack("H*", $bytes);
			return 0;
		}
	}
	
	Log3 $sname, 4, "$cname$retmsg TCPServer SendFrame wrote bytes 0x".unpack("H*", $bytes);

	return 1;
} # sendFrame

sub wolf_decodeDPTvalue($$$;$$) {
	my $name = shift;
	my $DPidvalue = shift;
	my $bytes = shift;
	my $translate = shift // 0; # optional default 0
	my $unit = shift // 0; # optional default 0
	my $value;
	
	my $dpid_type = $wolf_DPID_Types{$DPidvalue};
	my $dpt_type = $wolf_DPT_Types{$dpid_type->{DPT}};
	my $pdt_type = $wolf_PDT_Types{$dpt_type->{PDT}};
	
	Log3 $name, 5, "$name Decode: DPid: $DPidvalue DPT Type: $dpid_type->{DPT} PDT Type: $dpt_type->{PDT} bytes: 0x".unpack('H*',$bytes);
	
	#Decode
	if(defined($pdt_type->{Decode})) {
		Log3 $name, 5, "$name --> Start Decode";
		$value = $pdt_type->{Decode}->($name, $bytes);
		Log3 $name, 1, "$name Decode returned undef, Invalid value" if (!defined($value));
		Log3 $name, 5, "$name decoded value: $value";
	}
	
	#Translate
	if($translate && defined($dpt_type->{Translate})) {
		$value = $dpt_type->{Translate}[$value];	
		Log3 $name, 5, "$name translated value: $value";
	}
	
	#Unit
	if($unit && defined($dpt_type->{Unit})) {
		$value = "$value $dpt_type->{Unit}";
		Log3 $name, 5, "$name Unit: $dpt_type->{Unit} value: $value";
	}
	
	return $value;
}; # decodeDPTvalue

sub wolf_formatDPTvalue($$$;$$) {
	my $name = shift;
	my $DPidvalue = shift;
	my $decodedvalue = shift;
	my $translate = shift // 1; # optional default 0
	my $unit = shift // 0; # optional default 0
	my $value = $decodedvalue;
	
	my $dpid_type = $wolf_DPID_Types{$DPidvalue};
	my $dpt_type = $wolf_DPT_Types{$dpid_type->{DPT}};
	my $pdt_type = $wolf_PDT_Types{$dpt_type->{PDT}};
	
	Log3 $name, 5, "$name Decode: DPid: $DPidvalue DPT Type: $dpid_type->{DPT} PDT Type: $dpt_type->{PDT} decoded value: $decodedvalue";
		
	#Translate
	if($translate && defined($dpt_type->{Translate})) {
		if(defined($dpt_type->{Translate}[$decodedvalue])) {
			$value = $dpt_type->{Translate}[$decodedvalue];
		} else {
			$value = "$value (no translation found)";
		}
		Log3 $name, 5, "$name translated value: $value";
	}
	
	#Unit
	if($unit && defined($dpt_type->{Unit})) {
		$value = "$decodedvalue $dpt_type->{Unit}";
		Log3 $name, 5, "$name Unit: $dpt_type->{Unit} value: $value";
	}
	
	return $value;
}; # formatDPTvalue

sub wolf_encodeDPTvalue($$$;$$) {
	my $name = shift;
	my $DPidvalue = shift;
	my $value = shift;
	my $translate = shift // 0; # optional default 0 reverse translate
	my $unit = shift // 0; # optional default 0 remove unit
		
	my $dpid_type = $wolf_DPID_Types{$DPidvalue};
	my $dpt_type = $wolf_DPT_Types{$dpid_type->{DPT}};
	my $pdt_type = $wolf_PDT_Types{$dpt_type->{PDT}};
	
	Log3 $name, 5, "$name Encode: DPid: $DPidvalue DPT Type: $dpid_type->{DPT} PDT Type: $dpt_type->{PDT} raw value: 0x".unpack('H*',$value);
		
	#remove Unit
	if($unit && defined($dpt_type->{Unit})) {
		$value =~ s/$dpt_type->{Unit}//;
		chomp($value);
		Log3 $name, 5, "$name Removing Unit: $dpt_type->{Unit} Value: $value";
	}

	#reverse Translate
	if($translate && defined($dpt_type->{Translate})) {
		$value = grep( /^$value$/, $dpt_type->{Translate});	
		Log3 $name, 5, "$name reverse translated value: $value";
	}
	
	#Encode
	my $bytes;
	if(defined($pdt_type->{Encode})) {
		Log3 $name, 5, "$name --> Start Encode";
		$bytes = $pdt_type->{Encode}->($name, $value);
		Log3 $name, 5, "$name Encoded value: 0x".unpack("H*", $bytes);
	}
	
	return $bytes; # bytes
}; # encodeDPTvalue

sub wolf_getDPTArgs($$) {
	my $name = $_[0];
	my $DPidvalue = $_[1];
	
	my $dpid_type = $wolf_DPID_Types{$DPidvalue};
	my $dpt_type = $wolf_DPT_Types{$dpid_type->{DPT}};
	my $pdt_type = $wolf_PDT_Types{$dpt_type->{PDT}};
	
	my $write = defined($dpid_type->{Write}) && $dpid_type->{Write} ? $dpid_type->{Write} : 0;
	
	Log3 $name, 5, "$name Generating arguments list for DPID: $DPidvalue";
	return "" if(!$write);
	
	my @argslist;
	if( $write && defined($dpt_type->{Translate})) {
	
		my $i = 0;
		foreach my $value (@{$dpt_type->{Translate}}) {
			# only values in range
			if(!wolf_checkvaluerange($name, $DPidvalue, $i)) {
				$i++;
				next;
			}
			push @argslist, wolf_makeReadingName($value)." $i"; # "makereadingname originalindex"
			$i++;
		}
		
		#slider:slider,7,0.5,30
		return @argslist;
	} else {

		if($dpid_type->{DPT} eq "DPT_Date") {
			push @argslist, "datetime,timepicker:false,format:d.m.Y,inline:true 0"; # "value originalindex"
			return @argslist;
		} elsif($dpid_type->{DPT} eq "DPT_TimeOfDay") {
			push @argslist, "datetime,datepicker:false,format:H:i,inline:true 0"; # "value originalindex"
			return @argslist;
		}
	}
	
	my $rangesteps = wolf_checkvaluerange($name, $DPidvalue, undef);

	if($rangesteps->{Range} != 0 && $rangesteps->{Step} != 0) {
			
		my $start = $rangesteps->{Range}[0];
		my $end = $rangesteps->{Range}[1];
		my $step = $rangesteps->{Step};
	
		my $float = $step != 0 && ($step - int($step)) != 0;
		#Debug("--RANGE- $start-$end $step $float");
		
		push @argslist, "slider,$start,$step,$end,$float 0"; # "value originalindex"
		return @argslist;
	}
	
	return ""; # noArgs
}; # getDPTArgs

# msg format DPid Cmd Length ValueBytes
sub wolf_Parse($$) {
	my $hash = $_[0];
	my $name = $hash->{NAME};
	my $sname = $hash->{SNAME};
	
	$sname = $name if(!defined($sname));

	return if(IsDisabled($name));
	return if(IsDisabled($sname));

	# Dpid DPcmd DPlength DPvalue
	my ($DPid, $DPcmd, $DPlength, $DPvaluebytes) = split(/ /, $_[1], 4);
	
	Log3 $sname, 5, "$name Parse $DPid $DPcmd $DPlength 0x".unpack("H*", $DPvaluebytes);
	
	# get Datapoint settings
	my $dpid_type = $wolf_DPID_Types{$DPid};
	
	if(!defined($dpid_type)) {
		Log3 $sname, 1, "$name Unknown Datapoint ID $DPid";
		
		 if(AttrVal($sname, "createunknowndatapoints", 0)) {
			# Debug
			#Create dummy dpid for unknown datapoints
			my $dpt = "DPT_Scaling";
			$dpt = "DPT_Value_Temp" if($DPlength == 2);
			$dpt = "DPT_TimeOfDay" if($DPlength == 3);
			$dpt = "DPT_ActiveEnergy" if($DPlength == 4);
			$dpid_type = { Name => "Unknown $DPid", Device => "UNKNOWN", DPT => $dpt };
			$wolf_DPID_Types{$DPid} = $dpid_type;
		} else {
			return undef;
		}
	}
	
	my $dpt_type = $wolf_DPT_Types{$dpid_type->{DPT}};
	my $pdt_type = $wolf_PDT_Types{$dpt_type->{PDT}};
	
	my $DPName = $dpid_type->{Name};
	my $device = $dpid_type->{Device};
	my $alias = $wolf_DPT_Devices{$device};
	my $state = defined($dpid_type->{State}) ? $dpid_type->{State} : 0;
	my $unit = defined($dpt_type->{Unit}) ? $dpt_type->{Unit} : '';
	
	Log3 $name, 5, "$name DPTInfo DPid: $DPid DPT Type: ".$dpid_type->{DPT}." PDT Type: ".$dpt_type->{PDT}." Name: $DPName Device: $device Unit: $unit State: $state DeviceAlias: $alias";

	my $type = $defs{$sname}->{TYPE};
	my $devname = "wolf_${sname}_$device";
	if(!defined($modules{$type}{defptr}{$devname})) {
		# Unknown Device
		my $ret = "UNDEFINED $devname $type $device $alias";
		Log3 $sname, 2, "$name unknown/new device: \"$ret\" for DPID: $DPid Value bytes: 0x".unpack("H*", $DPvaluebytes);
		return $ret;
	}
	
	my $devhash = $modules{$type}{defptr}{$devname}; # get hash for device to update
		
	my $DecodedValue = wolf_decodeDPTvalue($devname,$DPid,$DPvaluebytes);
	
	if(!defined($DecodedValue)) {
		Log3 $devname, 1, "$devname Invalid Data for Datapoint: ID: $DPid Name: $DPName DPcmd: 0x".unpack('H*',$DPcmd)." Length: $DPlength bytes: 0x".unpack('H*',$DPvaluebytes)." decoded Value: undef Unit: $unit";
		return $devname; # no readings
	}

	#Format Value translate
	my $Value = wolf_formatDPTvalue($devname, $DPid, $DecodedValue, 1,0); # translate ,no unit
		
	Log3 $devname, 4, "$devname Datapoint: ID: $DPid Name: $DPName DPcmd: 0x".unpack('H*',$DPcmd)." Length: $DPlength bytes: 0x".unpack('H*',$DPvaluebytes)." decoded Value: $DecodedValue Value: $Value Unit: $unit";
	
	my $readingname = wolf_makeReadingName($DPName);
	Log3 $devname, 5, "$devname Datapoint: ID: $DPid using reading name: $readingname";
	
	readingsBeginUpdate($devhash);
	my $rv = readingsBulkUpdateIfChanged($devhash, "$readingname.DPID", $DPid);
	Log3 $devname, 4, "$devname Update reading $rv" if(defined($rv));

	$rv = readingsBulkUpdate($devhash, $readingname, $Value);
	Log3 $devname, 4, "$devname Update reading $rv";
	
	if($Value ne $DecodedValue) {
		$rv = readingsBulkUpdate($devhash, "$readingname.Value", $DecodedValue);
		Log3 $devname, 4, "$devname Update reading $rv" if(defined($rv));
	}

	if($unit) {
		$rv = readingsBulkUpdateIfChanged($devhash, "$readingname.Unit", $unit);
		Log3 $devname, 4, "$devname Update reading $rv" if(defined($rv));
	}

	#update state
	if($state) {
	
		my $stateval;
		foreach my $reading (split(/, ?/, $state)) {
			my $prefix;
			($reading, $prefix) = split(/:/, $reading);
			$reading = wolf_makeReadingName($reading);
			
			$stateval .= "$prefix:".ReadingsVal($devname, $reading, "")." ";
			Log3 $devname, 1, "$devname Update State with Reading \"$reading\" -> \"$stateval\"";
		}	
		chomp($stateval);
	
		$rv = readingsBulkUpdate($devhash, "state", $stateval);
		Log3 $devname, 4, "$devname Update reading $rv";
	}
	
	readingsEndUpdate($devhash, 1);
	
	return $devname;
} # Parse

sub wolf_Notify($$)
{
	my ($hash, $dev_hash) = @_;
	my $name = $hash->{NAME}; # own name / hash
 
	return "" if(IsDisabled($name)); # Return without any further action if the module is disabled
 
	return "" if($hash->{Device} ne "server"); # No events if not server
 
	my $devname = $dev_hash->{NAME}; # Device that created the events
	my $events = deviceEvents($dev_hash, 1);
	
	return if( !$events );

	if($devname eq "global")
	{
		foreach my $event (@{$events}) {
			$event = "" if(!defined($event));
			Log3 $name, 5, "$name Notify $devname $event";
			
			if(grep(m/^INITIALIZED|REREADCFG$/, $event))
			{
				wolf_InitServer($hash) if($hash->{Device} eq "server");
			}
    	}
	}
} # Notify

sub wolf_Get($@) {
	my ( $hash, $name, $cmd, @args ) = @_;
	
	return "Unknown argument $cmd, choose one of ";
} #Get

sub wolf_checkvaluerange($$$) {
	my $name = $_[0];
	my $DPidvalue = $_[1];
	my $value = $_[2];
		
	my $dpid_type = $wolf_DPID_Types{$DPidvalue};
	my $dpt_type = $wolf_DPT_Types{$dpid_type->{DPT}};
	#my $pdt_type = $wolf_PDT_Types{$dpt_type->{PDT}};
	
	# DPT Range
	my $range = defined($dpt_type->{Range}) ? $dpt_type->{Range} : 0;
	my $step = defined($dpt_type->{Step}) ? $dpt_type->{Step} : 0;

	# DPID Range
	$range = defined($dpid_type->{Range}) ? $dpid_type->{Range} : 0;
	$step = defined($dpid_type->{Step}) ? $dpid_type->{Step} : 0;

	# return range and step if value undef
	return {Range => $range, Step => $step} if(!defined($value));
	
	Log3 $name, 5, "$name Range check DPID: $DPidvalue Value: $value";
	
	# No Range
	return 1 if($range == 0);
	
	#TODO Step Round?
	
	#TODO Date Time
	
	my $count = scalar @{$range};
	#Debug("Count: $count");
	#
	my $i = 0;
	while($i<$count) {
		#Debug( $range->[$i]." --- ".$range->[$i + 1]);
		return 1 if( $value >= $range->[$i] && $value <= $range->[$i + 1]);
		$i += 2;
	}
		
	return 0;
} # checkvaluerange

sub wolf_Set($@) {
	my ( $hash, $name, $cmd, @args ) = @_;
	
	if($cmd eq "restartserver") {
		wolf_InitServer($hash);
	} elsif($cmd eq "wolf_parse") {
		wolf_Parse($hash, join(' ', @args));
	} elsif($cmd eq "wolf_reqall") {
		wolf_sendFrame($hash, 0xD0, undef, undef, undef, 0);
	} elsif($cmd eq "wolf_encode") {
		my ($dpid, $value) = @args;
		return "0x".unpack("H*", wolf_encodeDPTvalue($name, $dpid, $value));
	} elsif($cmd eq "wolf_decode") {
		my ($dpid, $value) = @args;
		$value =~ s/([[:xdigit:]]{2})/chr(hex($1))/eg;
		return wolf_formatDPTvalue($name, $dpid, wolf_decodeDPTvalue($name, $dpid, $value), 1 ,1);
	} elsif($cmd ne "?" && grep(/^$cmd$/, keys( %{$hash->{Inputs}}))) {	
		my $dpid = $hash->{Inputs}{$cmd};
		my $value = $args[0];
		
		Log3 $name, 5, "$name Set Input ID: $dpid Name: $cmd Value: $value";

		if(!defined($value)) {
			my $msg = "Missing Argument Value" ;
			Log3 $name, 1, "$name set $cmd $msg";
			return $msg;
		}

		my $dpid_type = $wolf_DPID_Types{$dpid};
		my $dpt_type = $wolf_DPT_Types{$dpid_type->{DPT}};
		
		if(defined($dpt_type->{Translate})) {
			#reverse translate  makeReadingName values
			my @argslist = wolf_getDPTArgs($name, $dpid); # "name originalindex"
			
			my @match = grep( s/^\Q$value\E\s//, @argslist);
			
			if(scalar @match != 1) {
				my $msg = "$name set $cmd Multiple/No matches for \"$value\"";
				Log3 $name, 1, $msg;
				return $msg;				
			}
			
			$value = $match[0];
		}

		# check range
		if(!wolf_checkvaluerange($name, $dpid, $value)) {
			my $msg = "$value Out of range" ;
			Log3 $name, 1, "$name set $cmd $msg";
			return $msg;
		};
		
		#		
		Log3 $name, 4, "$name Set Execute ID: $dpid Name: $cmd Value: $value";
		
		# encodeDPTvalue
		my $encodedvalue = wolf_encodeDPTvalue($name, $dpid, $value);
		Log3 $name, 4, "$name Set Execute ID: $dpid Name: $cmd EncodedValue: 0x".unpack("H*", $encodedvalue);
		
		# writeallowed inputs
		my $dry = !(AttrVal($name, "writeallowed", "false") eq "true");
		Log3 $name, 1, "$name Sent Value $dpid $cmd Dry run no changes will be made, see attribute writeallowed" if($dry);
		
		# send 
		wolf_sendFrame($hash, 0xC1, $dpid, $encodedvalue, undef, $dry); # dry run
		
		return "Dry run no changes made, see attribute writeallow" if($dry);
		
	} else {
		my $setlist = "";
		$setlist = "wolf_parse wolf_reqall restartserver wolf_encode wolf_decode" if($hash->{Device} eq "server");
		return "Unknown argument $cmd, choose one of $setlist".$hash->{InDatapoints};
	}
	
	return;
} # Set

sub wolf_Attr(@) {
	my ($cmd,$name,$attr_name,$attr_value) = @_;
	
	if($cmd eq "set") {
		return undef;
	}
	return undef;
} # Attr

sub wolf_makeReadingName($) {

	$_[0] =~ s/ä/ae/;
	$_[0] =~ s/ü/ue/;
	$_[0] =~ s/ö/oe/;
	$_[0] =~ s/Ä/Ae/;
	$_[0] =~ s/Ü/Ue/;
	$_[0] =~ s/Ö/Oe/;
	$_[0] =~ s/ß/ss/;

	return makeReadingName($_[0]);
}

1;

=pod
=begin html

<a name="wolf_ism8"></a>
<h3>Wolf ISM8</h3>
<ul>
    <i>wolf_ism8</i> provides an tcp server on default port 12004 for an Wolf ISM8 Module.<br>
	Will create devices for sets of defined datapoints.<br>
	e.g.<br>
		wolf_Heizung_HG1 ID 1-13,197-199<br>
		wolf_Heizung_BM1 ID 53-66,194<br>
		wolf_Heizung_MM1 ID 67-79<br>
		wolf_Heizung_MM2 ID 80-92<br>
    <br><br>
    <a name="wolf_ism8define"></a>
    <b>Define</b>
    <ul>
        <code>define &lt;name&gt; wolf_ism8 &lt;type&gt; &lt;alias&gt;</code>
        <br><br>
        Example: <code>define Heizung wolf_ism8</code>
		Example: <code>define wolf_Heizung_MM1 wolf_ism8 MM1</code>
        <br><br>
    </ul>
    <br>
    
    <a name="wolf_ism8set"></a>
    <b>Set</b><br>
    <ul>
        <code>set &lt;name&gt; &lt;option&gt; &lt;value&gt;</code>
        <br><br>
        Options:
        <ul>
            <li><i>restartserver</i><br>
                Restarts the server tcp server<br><br>
			</li>
			<li><i>wolf_reqall</i><br>
                Sends request all message to ISM8<br><br>
			</li>
  			<li><i>wolf_encode</i><br>
				ID Value<br>				
                Encode Datapoint Value<br><br>
			</li>
  			<li><i>wolf_decode</i><br>
				ID Value(hex notation)<br>				
                Decode Datapoint Value<br><br>
			</li>
			<li><i>wolf_parse</i><br>
				parse datapoint.<br>
				Format: id cmd value<br><br>
			</li>
        </ul>
    </ul>
    <br>

    <a name="wolf_ism8attr"></a>
    <b>Attributes</b>
    <ul>
        <code>attr &lt;name&gt; &lt;attribute&gt; &lt;value&gt;</code>
        <br><br>
        Attributes:
        <ul>
			<li><i>verbose</i> 1-5<br>
                Set verbosity level<br><br>
            </li>
            <li><i>LocalPort</i><br>
                Default: 12004<br>
				Server listen port<br><br>
            </li>
            <li><i>LocalAddr</i><br>
				Default: global (0.0.0.0)<br>
                Server listen address<br><br>
            </li>
            <li><i>writeallowed</i> true, false<br>
				default: false<br><br>
				Does not prevent sending of request responses and request for all datapoints<br><br>
            </li>
            <li><i>createunknowndatapoints</i> 0, 1<br>
                Default: 0<br><br>
				If 1 will create an wolf_[serverdevice]_UNKNOWN device with all unknown datapoints as readings.(unknown_[id])<br>
				Datatypes depend an value length.<br>
				1 byte = DPT_Scaling<br>
				2 bytes = DPT_Value_Temp<br>
				3 bytes = DPT_TimeOfDay<br>
				4 bytes	= DPT_ActiveEnergy<br><br>
            </li>
        </ul>
    </ul>
</ul>

=end html

=cut