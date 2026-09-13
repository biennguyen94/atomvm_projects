#
# This file is part of AtomVM.
#
# Copyright 2026 Bien Nguyen <nguyennhubientdh94@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
#

defmodule SnakeBlockbreakerClock.LunarDate do
  @moduledoc """
  Convert a Gregorian (solar) date to the Vietnamese lunar (âm lịch) date.

  Implementation of the Hồ Ngọc Đức "amlich" algorithm, tuned for Vietnam time
  (UTC+7). Validated against the reference implementation for solar dates from
  1900 to 2100.
  """

  @tz 7.0

  def jd_from_date(dd, mm, yy) do
    a = div(14 - mm, 12)
    y = yy + 4800 - a
    m = mm + 12 * a - 3
    jd = dd + div(153 * m + 2, 5) + 365 * y + div(y, 4) - div(y, 100) + div(y, 400) - 32045
    if jd < 2_299_161, do: dd + div(153 * m + 2, 5) + 365 * y + div(y, 4) - 32083, else: jd
  end

  def get_new_moon_day(k) do
    t = k / 1236.85
    t2 = t * t
    t3 = t2 * t

    jd1 =
      2415020.75933 + 29.53058868 * k + 0.0001178 * t2 -
        0.000000155 * t3 + 0.00033 * sin_deg(166.56 + 132.87 * t - 0.009173 * t2)

    m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3
    mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3
    f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3

    c1 = (0.1734 - 0.000393 * t) * sin_deg(m) + 0.0021 * sin_deg(2.0 * m)
    c1 = c1 - 0.4068 * sin_deg(mpr) + 0.0161 * sin_deg(2.0 * mpr)
    c1 = c1 - 0.0004 * sin_deg(3.0 * mpr)
    c1 = c1 + 0.0104 * sin_deg(2.0 * f) - 0.0051 * sin_deg(m + mpr)
    c1 = c1 - 0.0074 * sin_deg(m - mpr) + 0.0004 * sin_deg(2.0 * f + m)
    c1 = c1 - 0.0004 * sin_deg(2.0 * f - m) - 0.0006 * sin_deg(2.0 * f + mpr)
    c1 = c1 + 0.0010 * sin_deg(2.0 * f - mpr) + 0.0005 * sin_deg(2.0 * mpr + m)

    deltat =
      if t < -11.0 do
        0.001 + 0.000839 * t + 0.0002261 * t2 - 0.00000845 * t3 - 0.000000081 * t * t3
      else
        -0.000278 + 0.000265 * t + 0.000262 * t2
      end

    ifloor(jd1 + c1 - deltat + 0.5 + @tz / 24.0)
  end

  def get_sun_longitude(day_number) do
    t = (day_number - 0.5 - @tz / 24.0 - 2451545.0) / 36525.0
    t2 = t * t

    m = 357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2
    l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2

    dl = (1.914600 - 0.004817 * t - 0.000014 * t2) * sin_deg(m)
    dl = dl + (0.019993 - 0.000101 * t) * sin_deg(2.0 * m)
    dl = dl + 0.000290 * sin_deg(3.0 * m)

    l = (l0 + dl) * :math.pi() / 180.0
    l = l - 2.0 * :math.pi() * ifloor(l / (2.0 * :math.pi()))
    ifloor(l / :math.pi() * 6.0)
  end

  def get_lunar_month11(year) do
    off = jd_from_date(31, 12, year) - 2415021
    k = ifloor(off / 29.530588853)
    nm = get_new_moon_day(k)
    if get_sun_longitude(nm) >= 9, do: get_new_moon_day(k - 1), else: nm
  end

  def convert_solar_to_lunar(day, month, year) do
    day_number = jd_from_date(day, month, year)
    k = ifloor((day_number - 2415021.076998695) / 29.530588853)
    month_start = get_new_moon_day(k + 1)
    month_start = if month_start > day_number, do: get_new_moon_day(k), else: month_start

    a11 = get_lunar_month11(year)
    b11 = a11

    {lunar_year, a11, b11} =
      if a11 >= month_start do
        {year, get_lunar_month11(year - 1), b11}
      else
        {year + 1, a11, get_lunar_month11(year + 1)}
      end

    lunar_day = day_number - month_start + 1
    diff = ifloor((month_start - a11) / 29.0)
    lunar_month = diff + 11
    leap = false

    {lunar_month, leap} =
      if b11 - a11 > 365 do
        leap_month_diff = leap_month_offset(a11)

        if diff >= leap_month_diff do
          {diff + 10, diff == leap_month_diff}
        else
          {lunar_month, false}
        end
      else
        {lunar_month, leap}
      end

    lunar_month = if lunar_month > 12, do: lunar_month - 12, else: lunar_month
    lunar_year = if lunar_month >= 11 and diff < 4, do: lunar_year - 1, else: lunar_year

    {lunar_day, lunar_month, lunar_year, leap}
  end

  defp leap_month_offset(a11) do
    k = ifloor((a11 - 2415021.076998695) / 29.530588853 + 0.5)
    arc = get_sun_longitude(get_new_moon_day(k + 1))
    leap_loop(k, 1, arc)
  end

  defp leap_loop(k, i, arc) do
    last = arc
    new_i = i + 1
    new_arc = get_sun_longitude(get_new_moon_day(k + new_i))
    if new_arc != last and new_i < 14, do: leap_loop(k, new_i, new_arc), else: new_i - 1
  end

  defp sin_deg(deg), do: :math.sin(deg * :math.pi() / 180.0)

  defp ifloor(x) when is_integer(x), do: x

  defp ifloor(x) do
    t = trunc(x)
    if t > x, do: t - 1, else: t
  end
end