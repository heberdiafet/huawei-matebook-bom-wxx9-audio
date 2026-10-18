# SPDX-License-Identifier: GPL-2.0
#
# Out-of-tree build of snd-acp-legacy-mach with the ES83XX_HP_LOW quirk
# for Huawei BOM-WXX9 (MateBook 14/15 AMD) headphone output.
#
# The browser/consumer of this module is the AMD ACP3x machine driver that
# binds to the ESSX8336 codec on these boards.

obj-m := snd-acp-legacy-mach.o

snd-acp-legacy-mach-y := acp-legacy-mach.o acp3x-es83xx/acp3x-es83xx.o
