#!/usr/bin/env Rscript

# Publication-ready Figure 7. CUDA uses end-to-end elapsed time as the primary
# comparison; kernel-only time is retained in the source and summary tables.
source(file.path("scripts", "01_config_utils.R"))
required <- c("ggplot2","dplyr","tidyr","readr","scales","patchwork")
missing <- required[!vapply(required,requireNamespace,logical(1),quietly=TRUE)]
if(length(missing)) stop("Missing packages: ",paste(missing,collapse=", "))

raw_path <- file.path("outputs","tables","Table_Cross_Language_Runtime_Benchmark_Raw.csv")
if(!file.exists(raw_path)) stop("Run scripts/13_run_cross_language_benchmark.R first.")
raw <- readr::read_csv(raw_path,show_col_types=FALSE)
labels <- c(r_sequential="R sequential",r_psock="R/PSOCK (4 workers)",cpp_sequential="C++ sequential",
            cpp_openmp="C++/OpenMP (4 threads)",cpp_cuda="C++/CUDA (total)")
raw <- raw |> dplyr::mutate(mode=factor(labels[implementation],levels=unname(labels)))

elapsed <- raw |> dplyr::group_by(n_records,mode) |> dplyr::summarise(
  mean=mean(elapsed_sec),sd=sd(elapsed_sec),reps=dplyr::n(),se=sd/sqrt(reps),
  ci=stats::qt(.975,pmax(reps-1,1))*se,ymin=pmax(.Machine$double.eps,mean-ci),ymax=mean+ci,.groups="drop")
wide <- raw |> dplyr::select(n_records,rep,implementation,elapsed_sec) |>
  tidyr::pivot_wider(names_from=implementation,values_from=elapsed_sec)
if(!"cpp_cuda" %in% names(wide)) wide$cpp_cuda <- NA_real_
paired <- wide |>
  dplyr::mutate(language_gain=r_sequential/cpp_sequential,
                openmp_gain=cpp_sequential/cpp_openmp,
                gpu_gain=cpp_sequential/cpp_cuda,
                psock_openmp_gain=r_psock/cpp_openmp,
                psock_gpu_gain=r_psock/cpp_cuda) |>
  dplyr::select(n_records,rep,language_gain,openmp_gain,gpu_gain,psock_openmp_gain,psock_gpu_gain) |>
  tidyr::pivot_longer(-c(n_records,rep),names_to="comparison",values_to="speedup") |>
  dplyr::filter(!is.na(speedup)) |>
  dplyr::mutate(comparison=dplyr::recode(comparison,language_gain="R seq. / C++ seq.",
    openmp_gain="C++ seq. / OpenMP",gpu_gain="C++ seq. / CUDA total",
    psock_openmp_gain="R/PSOCK / OpenMP",psock_gpu_gain="R/PSOCK / CUDA total"))
speed <- paired |> dplyr::group_by(n_records,comparison) |> dplyr::summarise(
  mean=mean(speedup),sd=sd(speedup),reps=dplyr::n(),se=sd/sqrt(reps),
  ci=stats::qt(.975,pmax(reps-1,1))*se,ymin=pmax(0,mean-ci),ymax=mean+ci,.groups="drop")

source_dir <- file.path("outputs","tables","figure_source"); dir.create(source_dir,recursive=TRUE,showWarnings=FALSE)
readr::write_csv(elapsed,file.path(source_dir,"Figure_7_Source_Cross_Language_Elapsed_CI95.csv"))
readr::write_csv(speed,file.path(source_dir,"Figure_7_Source_Cross_Language_Paired_Speedup_CI95.csv"))
readr::write_csv(paired,file.path(source_dir,"Figure_7_Source_Cross_Language_Paired_Speedup_Raw.csv"))

cols <- c("R sequential"="#595959","R/PSOCK (4 workers)"="#CC79A7","C++ sequential"="#009E73",
          "C++/OpenMP (4 threads)"="#0072B2","C++/CUDA (total)"="#D55E00")
base_theme <- ggplot2::theme_minimal(base_size=14)+ggplot2::theme(
  panel.grid.minor=ggplot2::element_blank(),legend.position="bottom",
  plot.title=ggplot2::element_text(face="bold"),axis.title=ggplot2::element_text(size=15),
  plot.margin=ggplot2::margin(18,28,20,28))
breaks <- sort(unique(raw$n_records)); fmt <- function(x) ifelse(x>=1e6,paste0(format(x/1e6,nsmall=1),"M"),scales::comma(x))
p1 <- ggplot2::ggplot(elapsed,ggplot2::aes(n_records,mean,colour=mode,shape=mode,group=mode))+
  ggplot2::geom_errorbar(ggplot2::aes(ymin=ymin,ymax=ymax),width=.035,linewidth=.75)+
  ggplot2::geom_line(linewidth=1.1)+ggplot2::geom_point(size=3)+
  ggplot2::scale_x_log10(breaks=breaks,labels=fmt)+ggplot2::scale_y_log10()+
  ggplot2::scale_colour_manual(values=cols,drop=FALSE)+
  ggplot2::labs(title="A. Cross-language and heterogeneous-computing runtime",x=NULL,
                y="Mean elapsed time (s; log scale)",colour=NULL,shape=NULL)+base_theme
p2 <- ggplot2::ggplot(speed,ggplot2::aes(n_records,mean,colour=comparison,shape=comparison,group=comparison))+
  ggplot2::geom_hline(yintercept=1,linetype="dashed",colour="#6F6F6F")+
  ggplot2::geom_errorbar(ggplot2::aes(ymin=ymin,ymax=ymax),width=.035,linewidth=.75)+
  ggplot2::geom_line(linewidth=1.1)+ggplot2::geom_point(size=3)+
  ggplot2::scale_x_log10(breaks=breaks,labels=fmt)+
  ggplot2::labs(title="B. Paired implementation-specific speedup",x="Number of biospecimen profiles",
                y="Mean paired speedup ± 95% CI",colour=NULL,shape=NULL)+base_theme
figure <- p1/p2+patchwork::plot_layout(guides="collect")
dir.create(file.path("outputs","figures"),recursive=TRUE,showWarnings=FALSE)
ggplot2::ggsave(file.path("outputs","figures","Figure_7_Cross_Language_Runtime_Benchmark.pdf"),figure,width=9.8,height=7.4,bg="white")
ggplot2::ggsave(file.path("outputs","figures","Figure_7_Cross_Language_Runtime_Benchmark.png"),figure,width=9.8,height=7.4,dpi=600,bg="white")
log_message("Cross-language Figure 7 and source tables generated")
