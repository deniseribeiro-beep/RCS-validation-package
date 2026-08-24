#!/usr/bin/env Rscript
source(file.path("benchmark_v2", "config.R"))
required <- c("ggplot2", "patchwork", "scales")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Missing R packages for V2 outputs: ", paste(missing, collapse = ", "))

raw_path <- file.path(V2_TABLES, "Table_V2_Runtime_Benchmark_Raw.csv")
if (!file.exists(raw_path)) stop("Run benchmark_v2/02_run_benchmark.R first.")
raw <- read.csv(raw_path, stringsAsFactors = FALSE)
if (!nrow(raw) || any(raw$protocol_version != V2_PROTOCOL_VERSION) || any(!raw$equivalence_passed) ||
    any(!is.finite(raw$elapsed_sec)) || any(raw$elapsed_sec <= 0)) stop("Raw V2 results are invalid or incomplete.")

family_map <- c(r_sequential="R", r_psock="R", cython_sequential="Python/Cython",
                cython_openmp="Python/Cython", cpp_sequential="C++", cpp_openmp="C++", cpp_cuda="CUDA")
baseline_map <- c(R="r_sequential", `Python/Cython`="cython_sequential", `C++`="cpp_sequential")
parallel_map <- c(R="r_psock", `Python/Cython`="cython_openmp", `C++`="cpp_openmp")
raw$language_family <- unname(family_map[raw$implementation])

set.seed(V2_ORDER_SEED + 1L)
geomean <- function(x) exp(mean(log(x)))
bootstrap_ci <- function(x, statistic, reps=V2_BOOT_REPS) {
  x <- x[is.finite(x) & x > 0]
  if (length(x) == 1L) return(c(x, x))
  unname(stats::quantile(replicate(reps, statistic(sample(x, length(x), TRUE))), c(.025, .975), type=8))
}
summarize_runtime <- function(x) {
  ci <- bootstrap_ci(x$elapsed_sec, median)
  data.frame(protocol_version=V2_PROTOCOL_VERSION, language_family=x$language_family[1], n_records=x$n_records[1],
    implementation=x$implementation[1], workers=x$workers[1], timing_region=x$timing_region[1], repetitions=nrow(x),
    median_elapsed_sec=median(x$elapsed_sec), median_ci95_low_sec=ci[1], median_ci95_high_sec=ci[2],
    geometric_mean_elapsed_sec=geomean(x$elapsed_sec), mean_elapsed_sec=mean(x$elapsed_sec),
    sd_elapsed_sec=stats::sd(x$elapsed_sec), iqr_elapsed_sec=stats::IQR(x$elapsed_sec),
    cv_percent=stats::sd(x$elapsed_sec)/mean(x$elapsed_sec)*100,
    median_throughput_profiles_sec=median(x$throughput_profiles_sec),
    relative_ci_half_width_percent=(ci[2]-ci[1])/(2*median(x$elapsed_sec))*100,
    stability_passed=(ci[2]-ci[1])/(2*median(x$elapsed_sec)) <= .10)
}
groups <- split(raw, interaction(raw$n_records, raw$implementation, raw$workers, raw$timing_region, drop=TRUE))
summary_table <- do.call(rbind, lapply(groups, summarize_runtime)); rownames(summary_table) <- NULL
write.csv(summary_table, file.path(V2_TABLES, "Table_V2_Runtime_Benchmark_Summary.csv"), row.names=FALSE)

# Sequential-to-parallel speedups are paired only within the same language family.
parallel_raw <- raw[raw$language_family %in% names(baseline_map) &
                    raw$implementation == unname(parallel_map[raw$language_family]), ]
refs <- raw[raw$implementation == unname(baseline_map[raw$language_family]),
            c("language_family","n_records","repetition","timing_region","elapsed_sec")]
names(refs)[5] <- "sequential_elapsed_sec"
speedup_raw <- merge(parallel_raw, refs, by=c("language_family","n_records","repetition","timing_region"), all.x=TRUE)
speedup_raw$within_language_speedup <- speedup_raw$sequential_elapsed_sec / speedup_raw$elapsed_sec
speedup_raw$parallel_efficiency <- speedup_raw$within_language_speedup / speedup_raw$workers
write.csv(speedup_raw, file.path(V2_TABLES, "Table_V2_Within_Language_Speedup_Raw.csv"), row.names=FALSE)
summarize_speedup <- function(x) {
  ci <- bootstrap_ci(x$within_language_speedup, geomean)
  data.frame(language_family=x$language_family[1], n_records=x$n_records[1], implementation=x$implementation[1],
    workers=x$workers[1], timing_region=x$timing_region[1], repetitions=nrow(x),
    geometric_mean_speedup=geomean(x$within_language_speedup), speedup_ci95_low=ci[1], speedup_ci95_high=ci[2],
    median_speedup=median(x$within_language_speedup), median_efficiency=median(x$parallel_efficiency))
}
sg <- split(speedup_raw, interaction(speedup_raw$language_family, speedup_raw$n_records, speedup_raw$workers,
                                     speedup_raw$timing_region, drop=TRUE))
speedup_summary <- do.call(rbind, lapply(sg, summarize_speedup)); rownames(speedup_summary) <- NULL
write.csv(speedup_summary, file.path(V2_TABLES, "Table_V2_Within_Language_Speedup_Summary.csv"), row.names=FALSE)

equivalence <- aggregate(cbind(max_abs_pbio_diff,max_abs_rcs_diff) ~ language_family+implementation+workers, raw, max)
equivalence$all_equivalence_checks_passed <- TRUE
write.csv(equivalence, file.path(V2_TABLES, "Table_V2_Equivalence_Check.csv"), row.names=FALSE)
write.csv(summary_table[,c("language_family","n_records","implementation","workers","timing_region","repetitions",
                           "cv_percent","relative_ci_half_width_percent","stability_passed")],
          file.path(V2_TABLES, "Table_V2_Measurement_Stability.csv"), row.names=FALSE)

labels <- c(r_sequential="Sequential", r_psock="PSOCK parallel", cython_sequential="Sequential Cython",
            cython_openmp="Cython/OpenMP", cpp_sequential="Sequential", cpp_openmp="OpenMP")
palette <- c(r_sequential="#000000", r_psock="#CC79A7", cython_sequential="#E69F00",
             cython_openmp="#0072B2", cpp_sequential="#009E73", cpp_openmp="#56B4E9")
primary <- summary_table[summary_table$language_family %in% names(baseline_map) &
                         ((summary_table$implementation == unname(baseline_map[summary_table$language_family])) |
                         (summary_table$implementation == unname(parallel_map[summary_table$language_family]) &
                          summary_table$workers == V2_PRIMARY_WORKERS)), ]
primary$series <- ifelse(primary$workers == 1 & grepl("sequential", primary$implementation),
                         labels[primary$implementation], paste0(labels[primary$implementation], " (", primary$workers, ")"))

plot_runtime <- function(region, title) {
  d <- primary[primary$timing_region == region,]
  ggplot2::ggplot(d, ggplot2::aes(n_records, median_elapsed_sec, color=implementation, group=implementation)) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin=median_ci95_low_sec,ymax=median_ci95_high_sec,fill=implementation),
                         alpha=.12,color=NA,show.legend=FALSE) +
    ggplot2::geom_line(linewidth=.8) + ggplot2::geom_point(size=2.2) +
    ggplot2::facet_wrap(~language_family, ncol=1, scales="free_y") +
    ggplot2::scale_x_log10(breaks=sort(unique(d$n_records)),labels=scales::label_comma()) +
    ggplot2::scale_y_log10(labels=scales::label_number()) +
    ggplot2::scale_color_manual(values=palette,labels=labels) + ggplot2::scale_fill_manual(values=palette) +
    ggplot2::labs(title=title,x="Number of biospecimen profiles",y="Median elapsed time (s; log scale)",color=NULL) +
    ggplot2::theme_minimal(base_size=11) + ggplot2::theme(legend.position="bottom",panel.grid.minor=ggplot2::element_blank(),
      plot.title=ggplot2::element_text(face="bold"),plot.margin=ggplot2::margin(10,16,10,16))
}
runtime_figure <- plot_runtime("compute", "A. Steady-state classification (separate scale per language)") /
                  plot_runtime("end_to_end", "B. End-to-end execution (separate scale per language)") +
                  patchwork::plot_layout(guides="collect")
ggplot2::ggsave(file.path(V2_FIGURES,"Figure_6_V2_Sequential_Parallel_Runtime.pdf"),runtime_figure,
  width=10.5,height=14,device=if(capabilities("cairo")) grDevices::cairo_pdf else grDevices::pdf,bg="white")
ggplot2::ggsave(file.path(V2_FIGURES,"Figure_6_V2_Sequential_Parallel_Runtime.png"),runtime_figure,
  width=10.5,height=14,dpi=600,bg="white")
write.csv(primary,file.path(V2_TABLES,"Figure_6_V2_Source_Runtime.csv"),row.names=FALSE)

compute_speed <- speedup_summary[speedup_summary$timing_region == "compute",]
p_speed <- ggplot2::ggplot(compute_speed,ggplot2::aes(workers,geometric_mean_speedup,color=language_family,
                                                       group=interaction(language_family,n_records))) +
  ggplot2::geom_abline(slope=1,intercept=0,linetype=2,color="#777777") +
  ggplot2::geom_line() + ggplot2::geom_point(size=2.1) +
  ggplot2::facet_grid(language_family~n_records,labeller=ggplot2::labeller(n_records=scales::label_comma())) +
  ggplot2::scale_x_continuous(breaks=sort(unique(compute_speed$workers))) +
  ggplot2::labs(title="Within-language sequential-to-parallel speedup",x="Workers/threads",
                y="Paired geometric-mean speedup",color=NULL) +
  ggplot2::theme_minimal(base_size=10) + ggplot2::theme(legend.position="none",panel.grid.minor=ggplot2::element_blank(),
                                                        plot.title=ggplot2::element_text(face="bold"))
ggplot2::ggsave(file.path(V2_FIGURES,"Figure_S15_V2_Within_Language_Scaling.pdf"),p_speed,
  width=13,height=7,device=if(capabilities("cairo")) grDevices::cairo_pdf else grDevices::pdf,bg="white")
ggplot2::ggsave(file.path(V2_FIGURES,"Figure_S15_V2_Within_Language_Scaling.png"),p_speed,width=13,height=7,dpi=600,bg="white")
write.csv(compute_speed,file.path(V2_TABLES,"Figure_S15_V2_Source_Scaling.csv"),row.names=FALSE)

phase_cols <- c("read_sec","initialization_sec","classification_sec","write_sec","process_overhead_sec")
phase_raw <- raw[raw$timing_region=="end_to_end",c("language_family","n_records","repetition","implementation","workers",phase_cols)]
phase_long <- reshape(phase_raw,varying=phase_cols,v.names="elapsed_sec",timevar="phase",times=phase_cols,direction="long")
phase_summary <- aggregate(elapsed_sec ~ language_family+n_records+implementation+workers+phase,phase_long,median)
phase_summary$share_percent <- ave(phase_summary$elapsed_sec,interaction(phase_summary$language_family,phase_summary$n_records,
  phase_summary$implementation,phase_summary$workers),FUN=function(x) 100*x/sum(x))
write.csv(phase_summary,file.path(V2_TABLES,"Table_V2_End_to_End_Phase_Decomposition.csv"),row.names=FALSE)

cat("Benchmark V2 tables and figures generated without cross-language speedup comparisons.\n")
