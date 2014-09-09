/* 
 *	Copyright (C) 2003-2006 Gabest
 *	http://www.gabest.org
 *
 *  This Program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2, or (at your option)
 *  any later version.
 *   
 *  This Program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *   
 *  You should have received a copy of the GNU General Public License
 *  along with GNU Make; see the file COPYING.  If not, write to
 *  the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA. 
 *  http://www.gnu.org/copyleft/gpl.html
 *
 *  The "ArabicForms" table originates from fontforge
 *
 */

#include "stdafx.h"
#include "Arabic.h"

namespace ssf
{
	static const struct arabicforms 
	{
		unsigned short initial, medial, final, isolated;
		unsigned int isletter: 1;
		unsigned int joindual: 1;
		unsigned int required_lig_with_alef: 1;
	}
	ArabicForms[256] = 
	{
		{ 0x0600, 0x0600, 0x0600, 0x0600, 0, 0, 0 },
		{ 0x0601, 0x0601, 0x0601, 0x0601, 0, 0, 0 },
		{ 0x0602, 0x0602, 0x0602, 0x0602, 0, 0, 0 },
		{ 0x0603, 0x0603, 0x0603, 0x0603, 0, 0, 0 },
		{ 0x0000, 0x0000, 0x0000, 0x0000, 0, 0, 0 },
		{ 0x0000, 0x0000, 0x0000, 0x0000, 0, 0, 0 },
		{ 0x0000, 0x0000, 0x0000, 0x0000, 0, 0, 0 },
		{ 0x0000, 0x0000, 0x0000, 0x0000, 0, 0, 0 },
		{ 0x0000, 0x0000, 0x0000, 0x0000, 0, 0, 0 },
		{ 0x0000, 0x0000, 0x0000, 0x0000, 0, 0, 0 },
		{ 0x0000, 0x0000, 0x0000, 0x0000, 0, 0, 0 },
		{ 0x060b, 0x060b, 0x060b, 0x060b, 0, 0, 0 },
		{ 0x060c, 0x060c, 0x060c, 0x060c, 0, 0, 0 },
		{ 0x060d, 0x060d, 0x060d, 0x060d, 0, 0, 0 },
		{ 0x060e, 0x060e, 0x060e, 0x060e, 0, 0, 0 },
		{ 0x060f, 0x060f, 0x060f, 0x060f, 0, 0, 0 },
		{ 0x0610, 0x0610, 0x0610, 0x0610, 0, 0, 0 },
		{ 0x0611, 0x0611, 0x0611, 0x0611, 0, 0, 0 },
		{ 0x0612, 0x0612, 0x0612, 0x0612, 0, 0, 0 },
		{ 0x0613, 0x0613, 0x0613, 0x0613, 0, 0, 0 },
		{ 0x0614, 0x0614, 0x0614, 0x0614, 0, 0, 0 },
		{ 0x0615, 0x0615, 0x0615, 0x0615, 0, 0, 0 },
		{ 0x0000, 0x0000, 0x0000, 0x0000, 0, 0, 0 },
		{ 0x0000, 0x0000, 0x0000, 0x0000, 0, 0, 0 },
		{ 0x0000, 0x0000, 0x0000, 0x0000, 0, 0, 0 },
		{ 0x0000, 0x0000, 0x0000, 0x0000, 0, 0, 0 },
		{ 0x0000, 0x0000, 0x0000, 0x0000, 0, 0, 0 },
		{ 0x061b, 0x061b, 0x061b, 0x061b, 0, 0, 0 },
		{ 0x0000, 0x0000, 0x0000, 0x0000, 0, 0, 0 },
		{ 0x0000, 0x0000, 0x0000, 0x0000, 0, 0, 0 },
		{ 0x061e, 0x061e, 0x061e, 0x061e, 0, 0, 0 },
		{ 0x061f, 0x061f, 0x061f, 0x061f, 0, 0, 0 },
		{ 0x0000, 0x0000, 0x0000, 0x0000, 0, 0, 0 },
		{ 0x0621, 0x0621, 0x0621, 0xfe80, 1, 0, 0 },
		{ 0x0622, 0x0622, 0xfe82, 0xfe81, 1, 0, 0 },
		{ 0x0623, 0x0623, 0xfe84, 0xfe83, 1, 0, 0 },
		{ 0x0624, 0x0624, 0xfe86, 0xfe85, 1, 0, 0 },
		{ 0x0625, 0x0625, 0xfe88, 0xfe87, 1, 0, 0 },
		{ 0xfe8b, 0xfe8c, 0xfe8a, 0xfe89, 1, 1, 0 },
		{ 0x0627, 0x0627, 0xfe8e, 0xfe8d, 1, 0, 0 },
		{ 0xfe91, 0xfe92, 0xfe90, 0xfe8f, 1, 1, 0 },
		{ 0x0629, 0x0629, 0xfe94, 0xfe93, 1, 0, 0 },
		{ 0xfe97, 0xfe98, 0xfe96, 0xfe95, 1, 1, 0 },
		{ 0xfe9b, 0xfe9c, 0xfe9a, 0xfe99, 1, 1, 0 },
		{ 0xfe9f, 0xfea0, 0xfe9e, 0xfe9d, 1, 1, 0 },
		{ 0xfea3, 0xfea4, 0xfea2, 0xfea1, 1, 1, 0 },
		{ 0xfea7, 0xfea8, 0xfea6, 0xfea5, 1, 1, 0 },
		{ 0x062f, 0x062f, 0xfeaa, 0xfea9, 1, 0, 0 },
		{ 0x0630, 0x0630, 0xfeac, 0xfeab, 1, 0, 0 },
		{ 0x0631, 0x0631, 0xfeae, 0xfead, 1, 0, 0 },
		{ 0x0632, 0x0632, 0xfeb0, 0xfeaf, 1, 0, 0 },
		{ 0xfeb3, 0xfeb4, 0xfeb2, 0xfeb1, 1, 1, 0 },
		{ 0xfeb7, 0xfeb8, 0xfeb6, 0xfeb5, 1, 1, 0 },
		{ 0xfebb, 0xfebc, 0xfeba, 0xfeb9, 1, 1, 0 },
		{ 0xfebf, 0xfec0, 0xfebe, 0xfebd, 1, 1, 0 },
		{ 0xfec3, 0xfec4, 0xfec2, 0xfec1, 1, 1, 0 },
		{ 0xfec7, 0xfec8, 0xfec6, 0xfec5, 1, 1, 0 },
		{ 0xfecb, 0xfecc, 0xfeca, 0xfec9, 1, 1, 0 },
		{ 0xfecf, 0xfed0, 0xfece, 0xfecd, 1, 1, 0 },
		{ 0x0000, 0x0000, 0x0000, 0x0000, 0, 0, 0 },
		{ 0x0000, 0x0000, 0x0000, 0x0000, 0, 0, 0 },
		{ 0x0000, 0x0000, 0x0000, 0x0000, 0, 0, 0 },
		{ 0x0000, 0x0000, 0x0000, 0x0000, 0, 0, 0 },
		{ 0x0000, 0x0000, 0x0000, 0x0000, 0, 0, 0 },
		{ 0x0640, 0x0640, 0x0640, 0x0640, 0, 0, 0 },
		{ 0xfed3, 0xfed4, 0xfed2, 0xfed1, 1, 1, 0 },
		{ 0xfed7, 0xfed8, 0xfed6, 0xfed5, 1, 1, 0 },
		{ 0xfedb, 0xfedc, 0xfeda, 0xfed9, 1, 1, 0 },
		{ 0xfedf, 0xfee0, 0xfede, 0xfedd, 1, 1, 1 },
		{ 0xfee3, 0xfee4, 0xfee2, 0xfee1, 1, 1, 0 },
		{ 0xfee7, 0xfee8, 0xfee6, 0xfee5, 1, 1, 0 },
		{ 0xfeeb, 0xfeec, 0xfeea, 0xfee9, 1, 1, 0 },
		{ 0x0648, 0x0648, 0xfeee, 0xfeed, 1, 0, 0 },
		{ 0x0649, 0x0649, 0xfef0, 0xfeef, 1, 0, 0 },
		{ 0xfef3, 0xfef4, 0xfef2, 0xfef1, 1, 1, 0 },
		{ 0x064b, 0x064b, 0x064b, 0x064b, 0, 0, 0 },
		{ 0x064c, 0x064c, 0x064c, 0x064c, 0, 0, 0 },
		{ 0x064d, 0x064d, 0x064d, 0x064d, 0, 0, 0 },
		{ 0x064e, 0x064e, 0x064e, 0x064e, 0, 0, 0 },
		{ 0x064f, 0x064f, 0x064f, 0x064f, 0, 0, 0 },
		{ 0x0650, 0x0650, 0x0650, 0x0650, 0, 0, 0 },
		{ 0x0651, 0x0651, 0x0651, 0x0651, 0, 0, 0 },
		{ 0x0652, 0x0652, 0x0652, 0x0652, 0, 0, 0 },
		{ 0x0653, 0x0653, 0x0653, 0x0653, 0, 0, 0 },
		{ 0x0654, 0x0654, 0x0654, 0x0654, 0, 0, 0 },
		{ 0x0655, 0x0655, 0x0655, 0x0655, 0, 0, 0 },
		{ 0x0656, 0x0656, 0x0656, 0x0656, 0, 0, 0 },
		{ 0x0657, 0x0657, 0x0657, 0x0657, 0, 0, 0 },
		{ 0x0658, 0x0658, 0x0658, 0x0658, 0, 0, 0 },
		{ 0x0659, 0x0659, 0x0659, 0x0659, 0, 0, 0 },
		{ 0x065a, 0x065a, 0x065a, 0x065a, 0, 0, 0 },
		{ 0x065b, 0x065b, 0x065b, 0x065b, 0, 0, 0 },
		{ 0x065c, 0x065c, 0x065c, 0x065c, 0, 0, 0 },
		{ 0x065d, 0x065d, 0x065d, 0x065d, 0, 0, 0 },
		{ 0x065e, 0x065e, 0x065e, 0x065e, 0, 0, 0 },
		{ 0x0000, 0x0000, 0x0000, 0x0000, 0, 0, 0 },
		{ 0x0660, 0x0660, 0x0660, 0x0660, 0, 0, 0 },
		{ 0x0661, 0x0661, 0x0661, 0x0661, 0, 0, 0 },
		{ 0x0662, 0x0662, 0x0662, 0x0662, 0, 0, 0 },
		{ 0x0663, 0x0663, 0x0663, 0x0663, 0, 0, 0 },
		{ 0x0664, 0x0664, 0x0664, 0x0664, 0, 0, 0 },
		{ 0x0665, 0x0665, 0x0665, 0x0665, 0, 0, 0 },
		{ 0x0666, 0x0666, 0x0666, 0x0666, 0, 0, 0 },
		{ 0x0667, 0x0667, 0x0667, 0x0667, 0, 0, 0 },
		{ 0x0668, 0x0668, 0x0668, 0x0668, 0, 0, 0 },
		{ 0x0669, 0x0669, 0x0669, 0x0669, 0, 0, 0 },
		{ 0x066a, 0x066a, 0x066a, 0x066a, 0, 0, 0 },
		{ 0x066b, 0x066b, 0x066b, 0x066b, 0, 0, 0 },
		{ 0x066c, 0x066c, 0x066c, 0x066c, 0, 0, 0 },
		{ 0x066d, 0x066d, 0x066d, 0x066d, 0, 0, 0 },
		{ 0x066e, 0x066e, 0x066e, 0x066e, 1, 0, 0 },
		{ 0x066f, 0x066f, 0x066f, 0x066f, 1, 0, 0 },
		{ 0x0670, 0x0670, 0x0670, 0x0670, 1, 0, 0 },
		{ 0x0671, 0x0671, 0xfb51, 0xfb50, 1, 0, 0 },
		{ 0x0672, 0x0672, 0x0672, 0x0672, 1, 0, 0 },
		{ 0x0673, 0x0673, 0x0673, 0x0673, 1, 0, 0 },
		{ 0x0674, 0x0674, 0x0674, 0x0674, 1, 0, 0 },
		{ 0x0675, 0x0675, 0x0675, 0x0675, 1, 0, 0 },
		{ 0x0676, 0x0676, 0x0676, 0x0676, 1, 0, 0 },
		{ 0x0677, 0x0677, 0x0677, 0xfbdd, 1, 0, 0 },
		{ 0x0678, 0x0678, 0x0678, 0x0678, 1, 0, 0 },
		{ 0xfb68, 0xfb69, 0xfb67, 0xfb66, 1, 1, 0 },
		{ 0xfb60, 0xfb61, 0xfb5f, 0xfb5e, 1, 1, 0 },
		{ 0xfb54, 0xfb55, 0xfb53, 0xfb52, 1, 1, 0 },
		{ 0x067c, 0x067c, 0x067c, 0x067c, 1, 0, 0 },
		{ 0x067d, 0x067d, 0x067d, 0x067d, 1, 0, 0 },
		{ 0xfb58, 0xfb59, 0xfb57, 0xfb56, 1, 1, 0 },
		{ 0xfb64, 0xfb65, 0xfb63, 0xfb62, 1, 1, 0 },
		{ 0xfb5c, 0xfb5d, 0xfb5b, 0xfb5a, 1, 1, 0 },
		{ 0x0681, 0x0681, 0x0681, 0x0681, 1, 0, 0 },
		{ 0x0682, 0x0682, 0x0682, 0x0682, 1, 0, 0 },
		{ 0xfb78, 0xfb79, 0xfb77, 0xfb76, 1, 1, 0 },
		{ 0xfb74, 0xfb75, 0xfb73, 0xfb72, 1, 1, 0 },
		{ 0x0685, 0x0685, 0x0685, 0x0685, 1, 0, 0 },
		{ 0xfb7c, 0xfb7d, 0xfb7b, 0xfb7a, 1, 1, 0 },
		{ 0xfb80, 0xfb81, 0xfb7f, 0xfb7e, 1, 1, 0 },
		{ 0x0688, 0x0688, 0xfb89, 0xfb88, 1, 0, 0 },
		{ 0x0689, 0x0689, 0x0689, 0x0689, 1, 0, 0 },
		{ 0x068a, 0x068a, 0x068a, 0x068a, 1, 0, 0 },
		{ 0x068b, 0x068b, 0x068b, 0x068b, 1, 0, 0 },
		{ 0x068c, 0x068c, 0xfb85, 0xfb84, 1, 0, 0 },
		{ 0x068d, 0x068d, 0xfb83, 0xfb82, 1, 0, 0 },
		{ 0x068e, 0x068e, 0xfb87, 0xfb86, 1, 0, 0 },
		{ 0x068f, 0x068f, 0x068f, 0x068f, 1, 0, 0 },
		{ 0x0690, 0x0690, 0x0690, 0x0690, 1, 0, 0 },
		{ 0x0691, 0x0691, 0xfb8d, 0xfb8c, 1, 0, 0 },
		{ 0x0692, 0x0692, 0x0692, 0x0692, 1, 0, 0 },
		{ 0x0693, 0x0693, 0x0693, 0x0693, 1, 0, 0 },
		{ 0x0694, 0x0694, 0x0694, 0x0694, 1, 0, 0 },
		{ 0x0695, 0x0695, 0x0695, 0x0695, 1, 0, 0 },
		{ 0x0696, 0x0696, 0x0696, 0x0696, 1, 0, 0 },
		{ 0x0697, 0x0697, 0x0697, 0x0697, 1, 0, 0 },
		{ 0x0698, 0x0698, 0xfb8b, 0xfb8a, 1, 0, 0 },
		{ 0x0699, 0x0699, 0x0699, 0x0699, 1, 0, 0 },
		{ 0x069a, 0x069a, 0x069a, 0x069a, 1, 0, 0 },
		{ 0x069b, 0x069b, 0x069b, 0x069b, 1, 0, 0 },
		{ 0x069c, 0x069c, 0x069c, 0x069c, 1, 0, 0 },
		{ 0x069d, 0x069d, 0x069d, 0x069d, 1, 0, 0 },
		{ 0x069e, 0x069e, 0x069e, 0x069e, 1, 0, 0 },
		{ 0x069f, 0x069f, 0x069f, 0x069f, 1, 0, 0 },
		{ 0x06a0, 0x06a0, 0x06a0, 0x06a0, 1, 0, 0 },
		{ 0x06a1, 0x06a1, 0x06a1, 0x06a1, 1, 0, 0 },
		{ 0x06a2, 0x06a2, 0x06a2, 0x06a2, 1, 0, 0 },
		{ 0x06a3, 0x06a3, 0x06a3, 0x06a3, 1, 0, 0 },
		{ 0xfb6c, 0xfb6d, 0xfb6b, 0xfb6a, 1, 1, 0 },
		{ 0x06a5, 0x06a5, 0x06a5, 0x06a5, 1, 0, 0 },
		{ 0xfb70, 0xfb71, 0xfb6f, 0xfb6e, 1, 1, 0 },
		{ 0x06a7, 0x06a7, 0x06a7, 0x06a7, 1, 0, 0 },
		{ 0x06a8, 0x06a8, 0x06a8, 0x06a8, 1, 0, 0 },
		{ 0xfb90, 0xfb91, 0xfb8f, 0xfb8e, 1, 1, 0 },
		{ 0x06aa, 0x06aa, 0x06aa, 0x06aa, 1, 0, 0 },
		{ 0x06ab, 0x06ab, 0x06ab, 0x06ab, 1, 0, 0 },
		{ 0x06ac, 0x06ac, 0x06ac, 0x06ac, 1, 0, 0 },
		{ 0xfbd5, 0xfbd6, 0xfbd4, 0xfbd3, 1, 1, 0 },
		{ 0x06ae, 0x06ae, 0x06ae, 0x06ae, 1, 0, 0 },
		{ 0xfb94, 0xfb95, 0xfb93, 0xfb92, 1, 1, 0 },
		{ 0x06b0, 0x06b0, 0x06b0, 0x06b0, 1, 0, 0 },
		{ 0xfb9c, 0xfb9d, 0xfb9b, 0xfb9a, 1, 1, 0 },
		{ 0x06b2, 0x06b2, 0x06b2, 0x06b2, 1, 0, 0 },
		{ 0xfb98, 0xfb99, 0xfb97, 0xfb96, 1, 1, 0 },
		{ 0x06b4, 0x06b4, 0x06b4, 0x06b4, 1, 0, 0 },
		{ 0x06b5, 0x06b5, 0x06b5, 0x06b5, 1, 0, 0 },
		{ 0x06b6, 0x06b6, 0x06b6, 0x06b6, 1, 0, 0 },
		{ 0x06b7, 0x06b7, 0x06b7, 0x06b7, 1, 0, 0 },
		{ 0x06b8, 0x06b8, 0x06b8, 0x06b8, 1, 0, 0 },
		{ 0x06b9, 0x06b9, 0x06b9, 0x06b9, 1, 0, 0 },
		{ 0x06ba, 0x06ba, 0xfb9f, 0xfb9e, 1, 0, 0 },
		{ 0xfba2, 0xfba3, 0xfba1, 0xfba0, 1, 1, 0 },
		{ 0x06bc, 0x06bc, 0x06bc, 0x06bc, 1, 0, 0 },
		{ 0x06bd, 0x06bd, 0x06bd, 0x06bd, 1, 0, 0 },
		{ 0xfbac, 0xfbad, 0xfbab, 0xfbaa, 1, 1, 0 },
		{ 0x06bf, 0x06bf, 0x06bf, 0x06bf, 1, 0, 0 },
		{ 0x06c0, 0x06c0, 0xfba5, 0xfba4, 1, 0, 0 },
		{ 0xfba8, 0xfba9, 0xfba7, 0xfba6, 1, 1, 0 },
		{ 0x06c2, 0x06c2, 0x06c2, 0x06c2, 1, 0, 0 },
		{ 0x06c3, 0x06c3, 0x06c3, 0x06c3, 1, 0, 0 },
		{ 0x06c4, 0x06c4, 0x06c4, 0x06c4, 1, 0, 0 },
		{ 0x06c5, 0x06c5, 0xfbe1, 0xfbe0, 1, 0, 0 },
		{ 0x06c6, 0x06c6, 0xfbda, 0xfbd9, 1, 0, 0 },
		{ 0x06c7, 0x06c7, 0xfbd8, 0xfbd7, 1, 0, 0 },
		{ 0x06c8, 0x06c8, 0xfbdc, 0xfbdb, 1, 0, 0 },
		{ 0x06c9, 0x06c9, 0xfbe3, 0xfbe2, 1, 0, 0 },
		{ 0x06ca, 0x06ca, 0x06ca, 0x06ca, 1, 0, 0 },
		{ 0x06cb, 0x06cb, 0xfbdf, 0xfbde, 1, 0, 0 },
		{ 0xfbfe, 0xfbff, 0xfbfd, 0xfbfc, 1, 1, 0 },
		{ 0x06cd, 0x06cd, 0x06cd, 0x06cd, 1, 0, 0 },
		{ 0x06ce, 0x06ce, 0x06ce, 0x06ce, 1, 0, 0 },
		{ 0x06cf, 0x06cf, 0x06cf, 0x06cf, 1, 0, 0 },
		{ 0xfbe6, 0xfbe7, 0xfbe5, 0xfbe4, 1, 1, 0 },
		{ 0x06d1, 0x06d1, 0x06d1, 0x06d1, 1, 0, 0 },
		{ 0x06d2, 0x06d2, 0xfbaf, 0xfbae, 1, 0, 0 },
		{ 0x06d3, 0x06d3, 0xfbb1, 0xfbb0, 1, 0, 0 },
		{ 0x06d4, 0x06d4, 0x06d4, 0x06d4, 0, 0, 0 },
		{ 0x06d5, 0x06d5, 0x06d5, 0x06d5, 1, 0, 0 },
		{ 0x06d6, 0x06d6, 0x06d6, 0x06d6, 0, 0, 0 },
		{ 0x06d7, 0x06d7, 0x06d7, 0x06d7, 0, 0, 0 },
		{ 0x06d8, 0x06d8, 0x06d8, 0x06d8, 0, 0, 0 },
		{ 0x06d9, 0x06d9, 0x06d9, 0x06d9, 0, 0, 0 },
		{ 0x06da, 0x06da, 0x06da, 0x06da, 0, 0, 0 },
		{ 0x06db, 0x06db, 0x06db, 0x06db, 0, 0, 0 },
		{ 0x06dc, 0x06dc, 0x06dc, 0x06dc, 0, 0, 0 },
		{ 0x06dd, 0x06dd, 0x06dd, 0x06dd, 0, 0, 0 },
		{ 0x06de, 0x06de, 0x06de, 0x06de, 0, 0, 0 },
		{ 0x06df, 0x06df, 0x06df, 0x06df, 0, 0, 0 },
		{ 0x06e0, 0x06e0, 0x06e0, 0x06e0, 0, 0, 0 },
		{ 0x06e1, 0x06e1, 0x06e1, 0x06e1, 0, 0, 0 },
		{ 0x06e2, 0x06e2, 0x06e2, 0x06e2, 0, 0, 0 },
		{ 0x06e3, 0x06e3, 0x06e3, 0x06e3, 0, 0, 0 },
		{ 0x06e4, 0x06e4, 0x06e4, 0x06e4, 0, 0, 0 },
		{ 0x06e5, 0x06e5, 0x06e5, 0x06e5, 0, 0, 0 },
		{ 0x06e6, 0x06e6, 0x06e6, 0x06e6, 0, 0, 0 },
		{ 0x06e7, 0x06e7, 0x06e7, 0x06e7, 0, 0, 0 },
		{ 0x06e8, 0x06e8, 0x06e8, 0x06e8, 0, 0, 0 },
		{ 0x06e9, 0x06e9, 0x06e9, 0x06e9, 0, 0, 0 },
		{ 0x06ea, 0x06ea, 0x06ea, 0x06ea, 0, 0, 0 },
		{ 0x06eb, 0x06eb, 0x06eb, 0x06eb, 0, 0, 0 },
		{ 0x06ec, 0x06ec, 0x06ec, 0x06ec, 0, 0, 0 },
		{ 0x06ed, 0x06ed, 0x06ed, 0x06ed, 0, 0, 0 },
		{ 0x06ee, 0x06ee, 0x06ee, 0x06ee, 1, 0, 0 },
		{ 0x06ef, 0x06ef, 0x06ef, 0x06ef, 1, 0, 0 },
		{ 0x06f0, 0x06f0, 0x06f0, 0x06f0, 0, 0, 0 },
		{ 0x06f1, 0x06f1, 0x06f1, 0x06f1, 0, 0, 0 },
		{ 0x06f2, 0x06f2, 0x06f2, 0x06f2, 0, 0, 0 },
		{ 0x06f3, 0x06f3, 0x06f3, 0x06f3, 0, 0, 0 },
		{ 0x06f4, 0x06f4, 0x06f4, 0x06f4, 0, 0, 0 },
		{ 0x06f5, 0x06f5, 0x06f5, 0x06f5, 0, 0, 0 },
		{ 0x06f6, 0x06f6, 0x06f6, 0x06f6, 0, 0, 0 },
		{ 0x06f7, 0x06f7, 0x06f7, 0x06f7, 0, 0, 0 },
		{ 0x06f8, 0x06f8, 0x06f8, 0x06f8, 0, 0, 0 },
		{ 0x06f9, 0x06f9, 0x06f9, 0x06f9, 0, 0, 0 },
		{ 0x06fa, 0x06fa, 0x06fa, 0x06fa, 1, 0, 0 },
		{ 0x06fb, 0x06fb, 0x06fb, 0x06fb, 1, 0, 0 },
		{ 0x06fc, 0x06fc, 0x06fc, 0x06fc, 1, 0, 0 },
		{ 0x06fd, 0x06fd, 0x06fd, 0x06fd, 0, 0, 0 },
		{ 0x06fe, 0x06fe, 0x06fe, 0x06fe, 0, 0, 0 },
		{ 0x06ff, 0x06ff, 0x06ff, 0x06ff, 1, 0, 0 }
	};

	bool Arabic::IsArabic(WCHAR c)
	{
		return c >= 0x600 && c <= 0x6ff;
	}

	bool Arabic::Replace(WCHAR& c, pres_form_t pf)
	{
		if(!IsArabic(c)) return false;

		const arabicforms& af = ArabicForms[c - 0x600];

		switch(pf)
		{
		case isol: c = af.isolated; break;
		case init: c = af.initial; break;
		case medi: c = af.medial; break;
		case fina: c = af.final; break;
		}

		return true;
	}

	bool Arabic::Replace(WCHAR& c, WCHAR prev, WCHAR next)
	{
		if(!IsArabic(c)) return false;

		bool p = IsArabic(prev);
		bool n = IsArabic(next);

		return Replace(c, p ? (n ? medi : fina) : (n ? init : isol));
	}
}