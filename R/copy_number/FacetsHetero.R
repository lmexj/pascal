#!/usr/bin/env Rscript

pacman::p_load(dplyr,readr,tidyr,magrittr,purrr,stringr,rlist,crayon)

#------
# input
#------

if(file.exists('samples.yaml')) {  # use yaml file if available

message(green('using samples.yaml as sample list'))

	samples <-
		list.load('samples.yaml') %>%
		list.map(., as.data.frame(., stringsAsFactors=FALSE)) %>%
		bind_rows %>%
		rowwise %>%
		mutate(normal=gsub("^\\s+|\\s+$", '', normal)) %>%
		mutate(tumor=gsub("^\\s+|\\s+$", '', tumor)) %>%
		ungroup

} else if(file.exists('sample_sets.txt')) {  # otherwuse use sample sets file

message(yellow('using sample_sets.txt as sample list'))

	samples <-
		read.delim('sample_sets.txt',sep=' ',stringsAsFactors=FALSE,header=FALSE) %>%
		filter(!grepl("#",V1)) %>%
		(function(sets){
			tumor <-
				apply(sets,1, function(row) row %>% list.filter (. != '') %>% head(-1)) %>% unlist
			normal <-
				apply(sets,1, function(row) row %>% list.filter (. != '') %>% tail(1)) %>%
				rep(apply(sets,1,function(row) row %>% list.filter(. != '') %>% length-1))
			data.frame(normal,tumor,stringsAsFactors=FALSE) %>%
			tbl_df
		})

} else {

	message(red('no sample list available'))

}


#-------------------------
# create combined GATK vcf
#-------------------------

vcf.paths <-
	paste("ls ",samples$tumor %>% paste("gatk/vcf/",.,"_*.snps.filtered.vcf",sep="",collapse=" ")) %>%
	system(intern=TRUE)

dir.create('facets/gatk_variant_input', recursive=TRUE, showWarnings=FALSE)


#filter vcfs for quality & depth
vcf.paths %>%
substr(10,(nchar(.)-4)) %>%
lapply(. %>% paste("vcftools --vcf gatk/vcf/",.,".vcf --minGQ 20 --minDP 8 --recode --out facets/gatk_variant_input/",.,sep="") %>% system)

# gzip files
list.files("facets/gatk_variant_input",pattern="vcf$") %>%
list.filter(.!="all.variants.snps.filtered.recode.vcf") %>%
paste("bgzip -c facets/gatk_variant_input/",.," > facets/gatk_variant_input/",.,".gz",sep="") %>%
lapply(. %>% system)

# tabix files
list.files("facets/gatk_variant_input",pattern="vcf.gz$") %>%
paste("tabix -p vcf facets/gatk_variant_input/",.,sep="") %>%
lapply(. %>% system)

# combine variants into single file
list.files("facets/gatk_variant_input",pattern="vcf.gz$") %>%
paste("facets/gatk_variant_input/",.,sep="",collapse=" ") %>%
paste("vcf-merge ",.," > facets/gatk_variant_input/all.variants.snps.filtered.recode.vcf",sep="") %>%
system