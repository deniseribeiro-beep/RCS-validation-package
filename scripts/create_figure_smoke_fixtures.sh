#!/usr/bin/env bash
set -euo pipefail

root="${1:?Usage: create_figure_smoke_fixtures.sh <output-root>}"
tables="${root}/tables"
mkdir -p "${tables}"

# CI-only schema fixtures. These are not scientific or publication results.
cat > "${tables}/Table_Synthetic_Validation_Grade_Distribution.csv" <<'CSV'
matrix,scenario,expected_grade,final_grade,grade_route,n,proportion
fluid,optimal,Grade A,Grade A,Score-based certification,1,1
solid,optimal,Grade A,Grade A,Score-based certification,1,1
CSV

cat > "${tables}/Table_Combinatorial_Grade_Distribution.csv" <<'CSV'
matrix,final_grade,n,proportion,total
fluid,Grade A,20,0.20,100
fluid,Grade B,20,0.20,100
fluid,Grade C,20,0.20,100
fluid,Grade D,20,0.20,100
fluid,Grade E,20,0.20,100
solid,Grade A,20,0.20,100
solid,Grade B,20,0.20,100
solid,Grade C,20,0.20,100
solid,Grade D,20,0.20,100
solid,Grade E,20,0.20,100
CSV

threshold_file="${tables}/Table_Threshold_Transition_Detail.csv"
printf '%s\n' 'matrix,axis,axis_label,axis_order,perturbation_scenario,perturbation_fraction,baseline_weight,normalized_perturbed_weight,threshold_transition,transition_label,penalty_threshold,severity_required,severity_plot,reached' > "${threshold_file}"

fluid_axes=(P_pre P_cent1 P_cent2 P_post P_store)
solid_axes=(P_warm P_cold P_fix P_fixTime P_store)
transitions=("A to B" "B to C" "C to D" "D to E")
transition_labels=("A→B" "B→C" "C→D" "D→E")
perturbations=("-20%" "-10%" "nominal" "+10%" "+20%")
fractions=(-0.2 -0.1 0 0.1 0.2)

emit_threshold_rows() {
  local matrix="$1"
  shift
  local axes=("$@")
  local axis_index transition_index perturb_index reached
  for axis_index in "${!axes[@]}"; do
    for transition_index in "${!transitions[@]}"; do
      for perturb_index in "${!perturbations[@]}"; do
        reached=FALSE
        if [[ "$perturb_index" -eq 2 ]]; then reached=TRUE; fi
        printf '%s,%s,%s,%d,%s,%s,20,20,%s,%s,20,0.5,0.5,%s\n' \
          "$matrix" "${axes[$axis_index]}" "${axes[$axis_index]}" "$((axis_index + 1))" \
          "${perturbations[$perturb_index]}" "${fractions[$perturb_index]}" \
          "${transitions[$transition_index]}" "${transition_labels[$transition_index]}" "$reached" \
          >> "${threshold_file}"
      done
    done
  done
}

emit_threshold_rows fluid "${fluid_axes[@]}"
emit_threshold_rows solid "${solid_axes[@]}"

cat > "${tables}/Table_Benchmark_Runtime_Summary.csv" <<'CSV'
language_family,n_records,implementation,workers,timing_region,repetitions,median_elapsed_sec,median_ci95_low_sec,median_ci95_high_sec,geometric_mean_elapsed_sec,mean_elapsed_sec,sd_elapsed_sec,iqr_elapsed_sec,cv_percent,median_throughput_profiles_sec,relative_ci_half_width_percent,timing_outlier_count,precision_passed,smoke_variability_passed,stability_passed
C reference,10000,c_reference,1,compute,2,0.01,0.009,0.011,0.01,0.01,0.001,0.001,10,1000000,10,0,TRUE,TRUE,TRUE
C reference,10000,c_reference,1,end_to_end,2,0.02,0.019,0.021,0.02,0.02,0.001,0.001,5,500000,5,0,TRUE,TRUE,TRUE
C reference,5000000,c_reference,1,compute,2,1.0,0.9,1.1,1.0,1.0,0.1,0.1,10,5000000,10,0,TRUE,TRUE,TRUE
C reference,5000000,c_reference,1,end_to_end,2,1.2,1.1,1.3,1.2,1.2,0.1,0.1,8,4166667,8,0,TRUE,TRUE,TRUE
CSV

cat > "${tables}/Table_Benchmark_Within_Language_Speedup_Summary.csv" <<'CSV'
language_family,n_records,implementation,workers,timing_region,repetitions,geometric_mean_speedup,speedup_ci95_low,speedup_ci95_high,median_speedup,median_efficiency
R,5000000,r_psock,1,compute,2,1.0,0.95,1.05,1.0,1.0
R,5000000,r_psock,2,compute,2,1.4,1.3,1.5,1.4,0.7
R,5000000,r_psock,1,end_to_end,2,1.0,0.95,1.05,1.0,1.0
R,5000000,r_psock,2,end_to_end,2,1.2,1.1,1.3,1.2,0.6
Python/Cython,5000000,cython_openmp,1,compute,2,1.0,0.95,1.05,1.0,1.0
Python/Cython,5000000,cython_openmp,2,compute,2,1.5,1.4,1.6,1.5,0.75
Python/Cython,5000000,cython_openmp,1,end_to_end,2,1.0,0.95,1.05,1.0,1.0
Python/Cython,5000000,cython_openmp,2,end_to_end,2,1.3,1.2,1.4,1.3,0.65
C++,5000000,cpp_openmp,1,compute,2,1.0,0.95,1.05,1.0,1.0
C++,5000000,cpp_openmp,2,compute,2,1.6,1.5,1.7,1.6,0.8
C++,5000000,cpp_openmp,1,end_to_end,2,1.0,0.95,1.05,1.0,1.0
C++,5000000,cpp_openmp,2,end_to_end,2,1.4,1.3,1.5,1.4,0.7
CSV

cat > "${tables}/Table_Benchmark_CUDA_Speedup_Summary.csv" <<'CSV'
n_records,timing_region,repetitions,geometric_mean_speedup,speedup_ci95_low,speedup_ci95_high,median_speedup,iqr_speedup
10000,compute,2,2.0,1.8,2.2,2.0,0.1
5000000,compute,2,20.0,18.0,22.0,20.0,1.0
10000,end_to_end,2,0.8,0.7,0.9,0.8,0.05
5000000,end_to_end,2,1.2,1.1,1.3,1.2,0.05
CSV

printf 'Created CI-only figure schema fixtures in %s\n' "${tables}"
