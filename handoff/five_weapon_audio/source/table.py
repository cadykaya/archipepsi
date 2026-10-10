import sys, json
for r in json.load(open(sys.argv[1])):
    b = r['band_db']
    print("%-28s pk %5.1f tp %5.1f M %6.1f crest %4.1f cen %5d sub %5.1f low %5.1f mid %5.1f hi %5.1f air %5.1f -40@%.2f end %6.1f lead %.1f" % (r['file'][:28], r['peak_dbfs'], r['true_peak_dbtp'] or 0, r['momentary_max_lufs'], r['crest_db'], r['centroid_hz'], b['sub_20_80'], b['low_80_300'], b['mid_300_2k'], b['high_2k_8k'], b['air_8k_up'], r['decay_to_minus40_s'], r['last_20ms_peak_dbfs'], r['lead_ms']))
