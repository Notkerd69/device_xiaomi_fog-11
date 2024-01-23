#! /vendor/bin/sh

# Copyright (c) 2012-2013, 2016-2020, The Linux Foundation. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of The Linux Foundation nor
#       the names of its contributors may be used to endorse or promote
#       products derived from this software without specific prior written
#       permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NON-INFRINGEMENT ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

target=`getprop ro.board.platform`

function configure_memory_parameters() {
    # Set Memory parameters.
    #
    # Set per_process_reclaim tuning parameters
    # All targets will use vmpressure range 50-70,
    # All targets will use 512 pages swap size.
    #
    # Set Low memory killer minfree parameters
    # 32 bit Non-Go, all memory configurations will use 15K series
    # 32 bit Go, all memory configurations will use uLMK + Memcg
    # 64 bit will use Google default LMK series.
    #
    # Set ALMK parameters (usually above the highest minfree values)
    # vmpressure_file_min threshold is always set slightly higher
    # than LMK minfree's last bin value for all targets. It is calculated as
    # vmpressure_file_min = (last bin - second last bin ) + last bin
    #
    # Set allocstall_threshold to 0 for all targets.
    #
    # Read adj series and set adj threshold for PPR and ALMK.
    # This is required since adj values change from framework to framework.
    adj_series=`cat /sys/module/lowmemorykiller/parameters/adj`
    adj_1="${adj_series#*,}"
    set_almk_ppr_adj="${adj_1%%,*}"

    # PPR and ALMK should not act on HOME adj and below.
    # Normalized ADJ for HOME is 6. Hence multiply by 6
    # ADJ score represented as INT in LMK params, actual score can be in decimal
    # Hence add 6 considering a worst case of 0.9 conversion to INT (0.9*6).
    # For uLMK + Memcg, this will be set as 6 since adj is zero.
    set_almk_ppr_adj=$(((set_almk_ppr_adj * 6) + 6))
    echo $set_almk_ppr_adj > /sys/module/lowmemorykiller/parameters/adj_max_shift

    # Calculate vmpressure_file_min as below & set for 64 bit:
    # vmpressure_file_min = last_lmk_bin + (last_lmk_bin - last_but_one_lmk_bin)
    minfree_series=`cat /sys/module/lowmemorykiller/parameters/minfree`
    minfree_1="${minfree_series#*,}" ; rem_minfree_1="${minfree_1%%,*}"
    minfree_2="${minfree_1#*,}" ; rem_minfree_2="${minfree_2%%,*}"
    minfree_3="${minfree_2#*,}" ; rem_minfree_3="${minfree_3%%,*}"
    minfree_4="${minfree_3#*,}" ; rem_minfree_4="${minfree_4%%,*}"
    minfree_5="${minfree_4#*,}"

    vmpres_file_min=$((minfree_5 + (minfree_5 - rem_minfree_4)))
    echo $vmpres_file_min > /sys/module/lowmemorykiller/parameters/vmpressure_file_min
    echo "15360,19200,23040,26880,34415,43737" > /sys/module/lowmemorykiller/parameters/minfree

    # Enable adaptive LMK for all targets &
    # use Google default LMK series for all 64-bit targets >=2GB.
    # Enable oom_reaper
    echo 1 > /sys/module/lowmemorykiller/parameters/enable_adaptive_lmk
    echo 1 > /sys/module/lowmemorykiller/parameters/oom_reaper

    #Set PPR nomap parameters for bengal targets
    echo 1 > /sys/module/process_reclaim/parameters/enable_process_reclaim
    echo 50 > /sys/module/process_reclaim/parameters/pressure_min
    echo 70 > /sys/module/process_reclaim/parameters/pressure_max
    echo 30 > /sys/module/process_reclaim/parameters/swap_opt_eff
    echo 0 > /sys/module/process_reclaim/parameters/per_swap_size
    echo 7680 > /sys/module/process_reclaim/parameters/tsk_nomap_swap_sz

    # Set allocstall_threshold to 0 for all targets.
    echo 0 > /sys/module/vmpressure/parameters/allocstall_threshold

    # Disable wsf for all targets beacause we are using efk.
    # wsf Range : 1..1000 So set to bare minimum value 1.
    echo 1 > /proc/sys/vm/watermark_scale_factor
}

# Settings for bengal
echo N > /sys/module/lpm_levels/system/pwr/pwr-l2-gdhs/idle_enabled
echo N > /sys/module/lpm_levels/system/perf/perf-l2-gdhs/idle_enabled
echo N > /sys/module/lpm_levels/system/pwr/pwr-l2-gdhs/suspend_enabled
echo N > /sys/module/lpm_levels/system/perf/perf-l2-gdhs/suspend_enabled

if [ -f /sys/devices/soc0/soc_id ]; then
        soc_id=`cat /sys/devices/soc0/soc_id`
else
        soc_id=`cat /sys/devices/system/soc/soc0/id`
fi

case "$soc_id" in
        "417" | "420" | "444" | "445" | "469" | "470" )

    # Core control is temporarily disabled till bring up
    echo 0 > /sys/devices/system/cpu/cpu0/core_ctl/enable
    echo 2 > /sys/devices/system/cpu/cpu4/core_ctl/min_cpus
    # Core control parameters on big
    echo 40 > /sys/devices/system/cpu/cpu4/core_ctl/busy_down_thres
    echo 60 > /sys/devices/system/cpu/cpu4/core_ctl/busy_up_thres
    echo 100 > /sys/devices/system/cpu/cpu4/core_ctl/offline_delay_ms
    echo 4 > /sys/devices/system/cpu/cpu4/core_ctl/task_thres

    # Setting b.L scheduler parameters
    echo 67 > /proc/sys/kernel/sched_downmigrate
    echo 77 > /proc/sys/kernel/sched_upmigrate
    echo 85 > /proc/sys/kernel/sched_group_downmigrate
    echo 100 > /proc/sys/kernel/sched_group_upmigrate

    # cpuset settings
    echo 0-3 > /dev/cpuset/background/cpus
    echo 0-3 > /dev/cpuset/system-background/cpus

    # configure governor settings for little cluster
    echo "schedutil" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
    echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/up_rate_limit_us
    echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/down_rate_limit_us
    echo 1305600 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/hispeed_freq
    echo 614400 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
    echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/rtg_boost_freq

    # configure governor settings for big cluster
    echo "schedutil" > /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor
    echo 0 > /sys/devices/system/cpu/cpu4/cpufreq/schedutil/up_rate_limit_us
    echo 0 > /sys/devices/system/cpu/cpu4/cpufreq/schedutil/down_rate_limit_us
    echo 1401600 > /sys/devices/system/cpu/cpu4/cpufreq/schedutil/hispeed_freq
    echo 1056000 > /sys/devices/system/cpu/cpu4/cpufreq/scaling_min_freq
    echo 0 > /sys/devices/system/cpu/cpu4/cpufreq/schedutil/rtg_boost_freq

    echo "0:1017600" > /sys/devices/system/cpu/cpu_boost/input_boost_freq
    echo 80 > /sys/devices/system/cpu/cpu_boost/input_boost_ms
    echo 1 > /proc/sys/kernel/sched_walt_rotate_big_tasks

    # sched_load_boost as -6 is equivalent to target load as 85. It is per cpu tunable.
    echo -6 >  /sys/devices/system/cpu/cpu0/sched_load_boost
    echo -6 >  /sys/devices/system/cpu/cpu1/sched_load_boost
    echo -6 >  /sys/devices/system/cpu/cpu2/sched_load_boost
    echo -6 >  /sys/devices/system/cpu/cpu3/sched_load_boost
    echo -6 >  /sys/devices/system/cpu/cpu4/sched_load_boost
    echo -6 >  /sys/devices/system/cpu/cpu5/sched_load_boost
    echo -6 >  /sys/devices/system/cpu/cpu6/sched_load_boost
    echo -6 >  /sys/devices/system/cpu/cpu7/sched_load_boost
    echo 85 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/hispeed_load
    echo 85 > /sys/devices/system/cpu/cpu4/cpufreq/schedutil/hispeed_load

    # Set Memory parameters
    configure_memory_parameters

    # Enable bus-dcvs
    for device in /sys/devices/platform/soc
    do
        for cpubw in $device/*cpu-cpu-ddr-bw/devfreq/*cpu-cpu-ddr-bw
            do
            echo "bw_hwmon" > $cpubw/governor
            echo 50 > $cpubw/polling_interval
            echo 762 > $cpubw/min_freq
            echo "2288 3440 4173 5195 5859 7759 10322 11863 13763" > $cpubw/bw_hwmon/mbps_zones
            echo 85 > $cpubw/bw_hwmon/io_percent
            echo 4 > $cpubw/bw_hwmon/sample_ms
            echo 90 > $cpubw/bw_hwmon/decay_rate
            echo 190 > $cpubw/bw_hwmon/bw_step
            echo 20 > $cpubw/bw_hwmon/hist_memory
            echo 0 > $cpubw/bw_hwmon/hyst_length
            echo 80 > $cpubw/bw_hwmon/down_thres
            echo 0 > $cpubw/bw_hwmon/guard_band_mbps
            echo 250 > $cpubw/bw_hwmon/up_scale
            echo 1600 > $cpubw/bw_hwmon/idle_mbps
        done

        # memlat specific settings are moved to seperate file under
        # device/target specific folder
        for memlat in $device/*cpu*-lat/devfreq/*cpu*-lat
            do
            echo "mem_latency" > $memlat/governor
            echo 10 > $memlat/polling_interval
            echo 400 > $memlat/mem_latency/ratio_ceil
        done

        for latfloor in $device/*cpu*-ddr-latfloor*/devfreq/*cpu-ddr-latfloor*
        do
            echo "compute" > $latfloor/governor
            echo 10 > $latfloor/polling_interval
        done
    done

    # colcoation v3 disabled
    echo 0 > /proc/sys/kernel/sched_min_task_util_for_boost
    echo 0 > /proc/sys/kernel/sched_min_task_util_for_colocation

    # Turn off scheduler boost at the end
    echo 0 > /proc/sys/kernel/sched_boost

    # Turn on sleep modes
    echo 0 > /sys/module/lpm_levels/parameters/sleep_disabled
    ;;
esac

# Power/Perf tuning for khaje
case "$soc_id" in
        "518" )

    # Core control parameters on big
    echo 0 > /sys/devices/system/cpu/cpu0/core_ctl/enable
    echo 2 > /sys/devices/system/cpu/cpu4/core_ctl/min_cpus
    echo 40 > /sys/devices/system/cpu/cpu4/core_ctl/busy_down_thres
    echo 60 > /sys/devices/system/cpu/cpu4/core_ctl/busy_up_thres
    echo 100 > /sys/devices/system/cpu/cpu4/core_ctl/offline_delay_ms
    echo 4 > /sys/devices/system/cpu/cpu4/core_ctl/task_thres

    # Setting b.L scheduler parameters
    echo 65 > /proc/sys/kernel/sched_downmigrate
    echo 71 > /proc/sys/kernel/sched_upmigrate
    echo 85 > /proc/sys/kernel/sched_group_downmigrate
    echo 100 > /proc/sys/kernel/sched_group_upmigrate

    # cpuset settings
    echo 0-2     > /dev/cpuset/background/cpus
    echo 0-3     > /dev/cpuset/system-background/cpus
    echo 4-7     > /dev/cpuset/foreground/boost/cpus
    echo 0-2,4-7 > /dev/cpuset/foreground/cpus
    echo 0-7     > /dev/cpuset/top-app/cpus

    # configure governor settings for little cluster
    echo "schedutil" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
    echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/up_rate_limit_us
    echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/down_rate_limit_us
    echo 1516800 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/hispeed_freq
    echo 691200 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
    echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/rtg_boost_freq

    # configure governor settings for big cluster
    echo "schedutil" > /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor
    echo 0 > /sys/devices/system/cpu/cpu4/cpufreq/schedutil/up_rate_limit_us
    echo 0 > /sys/devices/system/cpu/cpu4/cpufreq/schedutil/down_rate_limit_us
    echo 1344000 > /sys/devices/system/cpu/cpu4/cpufreq/schedutil/hispeed_freq
    echo 1056000 > /sys/devices/system/cpu/cpu4/cpufreq/scaling_min_freq
    echo 0 > /sys/devices/system/cpu/cpu4/cpufreq/schedutil/rtg_boost_freq

    echo "0:1190000" > /sys/devices/system/cpu/cpu_boost/input_boost_freq
    echo 120 > /sys/devices/system/cpu/cpu_boost/input_boost_ms
    echo 1 > /proc/sys/kernel/sched_walt_rotate_big_tasks

    # sched_load_boost as -6 is equivalent to target load as 85. It is per cpu tunable.
    echo -6 >  /sys/devices/system/cpu/cpu0/sched_load_boost
    echo -6 >  /sys/devices/system/cpu/cpu1/sched_load_boost
    echo -6 >  /sys/devices/system/cpu/cpu2/sched_load_boost
    echo -6 >  /sys/devices/system/cpu/cpu3/sched_load_boost
    echo -6 >  /sys/devices/system/cpu/cpu4/sched_load_boost
    echo -6 >  /sys/devices/system/cpu/cpu5/sched_load_boost
    echo -6 >  /sys/devices/system/cpu/cpu6/sched_load_boost
    echo -6 >  /sys/devices/system/cpu/cpu7/sched_load_boost
    echo 85 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/hispeed_load
    echo 85 > /sys/devices/system/cpu/cpu4/cpufreq/schedutil/hispeed_load

    # Set Memory parameters
    configure_memory_parameters

    # Enable bus-dcvs
    for device in /sys/devices/platform/soc
    do
        for cpubw in $device/*cpu-cpu-ddr-bw/devfreq/*cpu-cpu-ddr-bw
            do
            echo "bw_hwmon" > $cpubw/governor
            echo 50 > $cpubw/polling_interval
            echo 762 > $cpubw/min_freq
            echo "2288 3440 4173 5195 5859 7759 10322 11863 13763 15960" > $cpubw/bw_hwmon/mbps_zones
            echo 85 > $cpubw/bw_hwmon/io_percent
            echo 4 > $cpubw/bw_hwmon/sample_ms
            echo 90 > $cpubw/bw_hwmon/decay_rate
            echo 190 > $cpubw/bw_hwmon/bw_step
            echo 20 > $cpubw/bw_hwmon/hist_memory
            echo 0 > $cpubw/bw_hwmon/hyst_length
            echo 80 > $cpubw/bw_hwmon/down_thres
            echo 0 > $cpubw/bw_hwmon/guard_band_mbps
            echo 250 > $cpubw/bw_hwmon/up_scale
            echo 1600 > $cpubw/bw_hwmon/idle_mbps
        done

        # memlat specific settings are moved to seperate file under
        # device/target specific folder
        for memlat in $device/*cpu*-lat/devfreq/*cpu*-lat
            do
            echo "mem_latency" > $memlat/governor
            echo 10 > $memlat/polling_interval
            echo 400 > $memlat/mem_latency/ratio_ceil
        done

        for latfloor in $device/*cpu*-ddr-latfloor*/devfreq/*cpu-ddr-latfloor*
        do
            echo "compute" > $latfloor/governor
            echo 10 > $latfloor/polling_interval
        done
    done

    # colcoation v3 disabled
    echo 0 > /proc/sys/kernel/sched_min_task_util_for_boost
    echo 0 > /proc/sys/kernel/sched_min_task_util_for_colocation

    # Turn off scheduler boost at the end
    echo 0 > /proc/sys/kernel/sched_boost

    # Turn on sleep modes
    echo 0 > /sys/module/lpm_levels/parameters/sleep_disabled
    ;;
esac

# Power/Perf tuning for scuba
case "$soc_id" in
        "441" | "471" | "473" | "474" )

    # Quad-core device. disable core_ctl
    echo 0 > /sys/devices/system/cpu/cpu0/core_ctl/enable

    # Configure schedutil governor settings
    echo "schedutil" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
    echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/up_rate_limit_us
    echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/down_rate_limit_us
    echo 1305600 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/hispeed_freq
    echo 614400 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
    echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/rtg_boost_freq

    # sched_load_boost as -6 is equivalent to target load as 85.
    echo 0 > /proc/sys/kernel/sched_boost
    echo -6 > /sys/devices/system/cpu/cpu0/sched_load_boost
    echo -6 > /sys/devices/system/cpu/cpu1/sched_load_boost
    echo -6 > /sys/devices/system/cpu/cpu2/sched_load_boost
    echo -6 > /sys/devices/system/cpu/cpu3/sched_load_boost
    echo 85 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/hispeed_load

    # Set Memory parameters
    configure_memory_parameters

    # Enable bus-dcvs
    for device in /sys/devices/platform/soc
    do
        for cpubw in $device/*cpu-cpu-ddr-bw/devfreq/*cpu-cpu-ddr-bw
            do
            echo "bw_hwmon" > $cpubw/governor
            echo 50 > $cpubw/polling_interval
            echo 762 > $cpubw/min_freq
            echo "2288 3440 4173 5195 5859 7759 10322 11863 13763" > $cpubw/bw_hwmon/mbps_zones
            echo 85 > $cpubw/bw_hwmon/io_percent
            echo 4 > $cpubw/bw_hwmon/sample_ms
            echo 90 > $cpubw/bw_hwmon/decay_rate
            echo 190 > $cpubw/bw_hwmon/bw_step
            echo 20 > $cpubw/bw_hwmon/hist_memory
            echo 0 > $cpubw/bw_hwmon/hyst_length
            echo 80 > $cpubw/bw_hwmon/down_thres
            echo 0 > $cpubw/bw_hwmon/guard_band_mbps
            echo 250 > $cpubw/bw_hwmon/up_scale
            echo 1600 > $cpubw/bw_hwmon/idle_mbps
        done

        # memlat specific settings are moved to seperate file under
        # device/target specific folder
        for memlat in $device/*cpu*-lat/devfreq/*cpu*-lat
            do
            echo "mem_latency" > $memlat/governor
            echo 10 > $memlat/polling_interval
            echo 400 > $memlat/mem_latency/ratio_ceil
        done

        for latfloor in $device/*cpu*-ddr-latfloor*/devfreq/*cpu-ddr-latfloor*
        do
            echo "compute" > $latfloor/governor
            echo 10 > $latfloor/polling_interval
        done
    done

    # Turn on sleep modes
    echo 0 > /sys/module/lpm_levels/parameters/sleep_disabled
    ;;
esac

setprop vendor.post_boot.parsed 1
