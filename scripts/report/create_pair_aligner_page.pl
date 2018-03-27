#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


=head1 NAME

create_pair_aligner_page.pl

=head1 AUTHORS

Kathryn Beal

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 COPYRIGHT

This modules is part of the Ensembl project http://www.ensembl.org

=head1 DESCRIPTION

This script will output a html document for a pairwise alignment showing the configuration parameters and coverage

=head1 SYNOPSIS

 perl ~/work/projects/tests/test_config/create_pair_aligner_page.pl --config_url mysql://ensadmin:${ENSADMIN_PSW}\@compara1:3306/kb3_pair_aligner_config --mlss_id 455 > pair_aligner_455.html

perl create_pair_aligner_page.pl
   --config_url pair aligner configuration database
   --mlss_id method_link_species_set_id
   [image_dir /path/to/write/image]

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

  Prints help message and exits.

=back

=head2 CONFIGURATION

=over

=item B<--config_url mysql://user[:passwd]@host[:port]/dbname]>

Location of the configuration database

=item B<--mlss_id method_link_species_set_id>

Method link species set id of the pairwise alignment

=item B<[--image_location /path/to/write/image]>

Directory to write image files. Default current working directory

=back

=cut

use warnings;
use strict;

use Getopt::Long;
use DBI;
use HTML::Template;
use Number::Format qw(:subs :vars);
use File::Basename;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::IO qw/:spurt/;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

my $usage = qq{
perl update_config_database.pl
  Getting help:
    [--help]

  Options:
   --config_url mysql://user[:passwd]\@host[:port]/dbname
      Location of the configuration database

   --mlss_id method_link_species_set_id
      Method link species set id of the pairwise alignment

   [--image_location Directory to write image files. Default cwd]

};

my $help;
my $mlss_id;
my $compara_url;
my $ucsc_url;
my $urls;
my $image_dir = "./"; #location to write image files
my $R_prog = "R";  # Whatever is in $PATH
my $reg = "Bio::EnsEMBL::Registry";


my $this_directory = dirname($0);

my $blastz_template= "$this_directory/pair_aligner_blastz_page.tmpl";
my $tblat_template= "$this_directory/pair_aligner_tblat_page.tmpl";
my $no_config_template= "$this_directory/pair_aligner_no_config_page.tmpl";
my $ucsc_template = "$this_directory/pair_aligner_ucsc_page.tmpl";

my $references = {
       BlastZ => "<a href=\"http://www.genome.org/cgi/content/abstract/13/1/103\">Schwartz S et al., Genome Res.;13(1):103-7</a>, <a href=\"http://www.pnas.org/cgi/content/full/100/20/11484\">Kent WJ et al., Proc Natl Acad Sci U S A., 2003;100(20):11484-9</a>",

       LastZ => "<a href=\"http://www.bx.psu.edu/miller_lab/dist/README.lastz-1.02.00/README.lastz-1.02.00a.html\">LastZ</a>",
       "Translated Blat" => "<a href=\"http://www.genome.org/cgi/content/abstract/12/4/656\">Kent W, Genome Res., 2002;12(4):656-64</a>"};

#Set default parameters. Other parameters will be listed under "Additional parameters"
my $blastz_options;
%$blastz_options = ('O' => "Gap open penalty (O)",
		    'E' => "Gap extend penalty (E)",
		    'K' => "HSP threshold (K)",
		    'L' => "Threshold for gapped extension (L)",
		    'H' => "Threshold for alignments between gapped alignment blocks (H)",
		    'M' => "Masking count (M)",
		    'T' => "Seed and Transition value (T)",
		    'Q' => "Scoring matrix (Q)");

#Current blastz_parameters (set defaults)
my $blastz_parameters;
%$blastz_parameters = ('O' => 400,
		       'E' => 30,
		       'K' => 3000,
		       'T' => 1);

GetOptions(
           "help" => \$help,
	   "url=s" => \@$urls,
	   "compara_url=s" => \$compara_url,
	   "mlss|mlss_id|method_link_species_set_id=s" => \$mlss_id,
	   "image_location=s" => \$image_dir,
	   "ucsc_url=s" => \$ucsc_url,
  );

# Print Help and exit
if ($help) {
  print $usage;
  exit(0);
}

#Make sure image_dir ends in a "/"
if ($image_dir !~ /\/$/) {
    $image_dir .= "/";
}

#load core database in order to get common name
if ($urls) {
    foreach my $url (@$urls) {
	$reg->load_registry_from_url($url);
    }
}

#Fetch data from the configuration database
my ($alignment_results, $ref_results, $non_ref_results, $pair_aligner_config, $tblat_parameters, $ref_dna_collection_config, $non_ref_dna_collection_config);

($alignment_results, $ref_results, $non_ref_results, $pair_aligner_config, $blastz_parameters, $tblat_parameters, $ref_dna_collection_config, $non_ref_dna_collection_config) = fetch_input($compara_url, $mlss_id);

# open the correct html template
my $template;

#Check if downloaded from ucsc
if ($pair_aligner_config->{download_url}) {
    $ucsc_url = $pair_aligner_config->{download_url};
}

if (defined $ucsc_url) {
    
    $template = HTML::Template->new(filename => $ucsc_template);
    my $ucsc_html = "<a href=\"" . $ucsc_url . "\">UCSC</a>";
    $template->param(UCSC_URL => $ucsc_html);
} elsif ($pair_aligner_config->{method_link_type} eq "BLASTZ_NET" || 
    $pair_aligner_config->{method_link_type} eq "LASTZ_NET") {

    #Check if have results
    if (keys %$blastz_parameters) {
	#Open blastz/lastz template
	$template = HTML::Template->new(filename => $blastz_template);
    } else {
	$template = HTML::Template->new(filename => $no_config_template);
	$template->param(CONFIG => "No configuration parameters are available");
    }
} elsif ($pair_aligner_config->{method_link_type} eq "TRANSLATED_BLAT_NET") {
    #Check if have results
    if (%$tblat_parameters) {
	#Open blastz/lastz template
	$template = HTML::Template->new(filename => $tblat_template);
    } else {
	$template = HTML::Template->new(filename => $no_config_template);
	$template->param(CONFIG => "No configuration parameters are available");
    }
} else {
    throw("Unsupported method_link_type " . $pair_aligner_config->{method_link_type} . "\n");
}

#Prettify the method_link_type
my $type;
if ($pair_aligner_config->{method_link_type} eq "BLASTZ_NET") {
    $type = "BlastZ";
} elsif ($pair_aligner_config->{method_link_type} eq "LASTZ_NET") {
    $type = "LastZ";
} elsif ($pair_aligner_config->{method_link_type} eq "TRANSLATED_BLAT_NET") {
    $type = "Translated Blat";
}

#Set html template variables for introduction
$template->param(REF_NAME => $ref_dna_collection_config->{common_name});
$template->param(NON_REF_NAME => $non_ref_dna_collection_config->{common_name});
$template->param(REF_SPECIES => pretty_name($ref_dna_collection_config->{name}));
$template->param(NON_REF_SPECIES => pretty_name($non_ref_dna_collection_config->{name}));
$template->param(REF_ASSEMBLY => $ref_results->{assembly});
$template->param(NON_REF_ASSEMBLY => $non_ref_results->{assembly});
$template->param(METHOD_TYPE => $type);
$template->param(ENSEMBL_RELEASE => $pair_aligner_config->{ensembl_release});

#Parameters NOT used for ucsc page
unless (defined $ucsc_url) {
    $template->param(REFERENCE => $references->{$type});

}

#Set html template variables for configuration parameters
if ($pair_aligner_config->{method_link_type} eq "BLASTZ_NET" || 
    $pair_aligner_config->{method_link_type} eq "LASTZ_NET") {

    if (keys %$blastz_parameters) {
	$template->param(BLASTZ_O => $blastz_parameters->{O});
	$template->param(BLASTZ_E => $blastz_parameters->{E});
	$template->param(BLASTZ_K => $blastz_parameters->{K});
	$template->param(BLASTZ_L => $blastz_parameters->{L});
	$template->param(BLASTZ_H => $blastz_parameters->{H});
	$template->param(BLASTZ_M => $blastz_parameters->{M});
	$template->param(BLASTZ_T => $blastz_parameters->{T});

	if ($blastz_parameters->{other}) {
	    $template->param(BLASTZ_OTHER => $blastz_parameters->{other});
	}
	
	if (defined $blastz_parameters->{Q} && $blastz_parameters->{Q} ne "" ) {
	    #my $matrix = create_matrix_table($blastz_parameters->{Q});
	    #$template->param(BLASTZ_Q => $matrix);
	} else {
	    $template->param(BLASTZ_Q => "Default");
	}

	$template->param(REF_CHUNK_SIZE => format_number($ref_dna_collection_config->{chunk_size}));
	$template->param(REF_OVERLAP => format_number($ref_dna_collection_config->{overlap}));
	$template->param(REF_GROUP_SET_SIZE => format_number($ref_dna_collection_config->{group_set_size}));
	$template->param(NON_REF_CHUNK_SIZE => format_number($non_ref_dna_collection_config->{chunk_size}));
	$template->param(NON_REF_OVERLAP => format_number($non_ref_dna_collection_config->{overlap}));
	$template->param(NON_REF_GROUP_SET_SIZE => format_number($non_ref_dna_collection_config->{group_set_size}));
	#Masking variables
	$template->param(REF_MASKING => $ref_dna_collection_config->{masking_options}) if ($ref_dna_collection_config->{masking_options});
	$template->param(REF_MASKING => $ref_dna_collection_config->{masking_options_file}) if ($ref_dna_collection_config->{masking_options_file});

	$template->param(NON_REF_MASKING => $non_ref_dna_collection_config->{masking_options}) if ($non_ref_dna_collection_config->{masking_options});
	$template->param(NON_REF_MASKING => $non_ref_dna_collection_config->{masking_options_file}) if ($non_ref_dna_collection_config->{masking_options_file});
	
    }
} elsif ($pair_aligner_config->{method_link_type} eq "TRANSLATED_BLAT_NET" &&
	defined $tblat_parameters->{minScore} && 
	defined $tblat_parameters->{t} && 
	defined $tblat_parameters->{q}) {
    
    #Need to be within check for parameters
    $template->param(TBLAT_MINSCORE => $tblat_parameters->{minScore});
    $template->param(TBLAT_T => $tblat_parameters->{t});
    $template->param(TBLAT_Q => $tblat_parameters->{q});
    $template->param(TBLAT_MASK => $tblat_parameters->{mask});
    $template->param(TBLAT_QMASK => $tblat_parameters->{qMask});

    $template->param(REF_CHUNK_SIZE => format_number($ref_dna_collection_config->{chunk_size}));
    $template->param(REF_OVERLAP => format_number($ref_dna_collection_config->{overlap}));
    $template->param(REF_GROUP_SET_SIZE => format_number($ref_dna_collection_config->{group_set_size}));
    $template->param(NON_REF_CHUNK_SIZE => format_number($non_ref_dna_collection_config->{chunk_size}));
    $template->param(NON_REF_OVERLAP => format_number($non_ref_dna_collection_config->{overlap}));
    $template->param(NON_REF_GROUP_SET_SIZE => format_number($non_ref_dna_collection_config->{group_set_size}));
    #Masking variables
    $template->param(REF_MASKING => $ref_dna_collection_config->{masking_options}) if ($ref_dna_collection_config->{masking_options});
    $template->param(REF_MASKING => $ref_dna_collection_config->{masking_options_file}) if ($ref_dna_collection_config->{masking_options_file});
    $template->param(NON_REF_MASKING => $non_ref_dna_collection_config->{masking_options}) if ($non_ref_dna_collection_config->{masking_options});
    $template->param(NON_REF_MASKING => $non_ref_dna_collection_config->{masking_options_file}) if ($non_ref_dna_collection_config->{masking_options_file});
    
}

#Chunk parameters

#Set html template variables for results
$template->param(NUM_BLOCKS => $alignment_results->{num_blocks});

my $ref_uncovered = $ref_results->{length}-$ref_results->{alignment_coverage};

$template->param(REF_GENOME_SIZE => format_number($ref_results->{length}));
$template->param(REF_GENOME_COVERED => format_number($ref_results->{alignment_coverage}));
$template->param(REF_GENOME_UNCOVERED => format_number($ref_uncovered));

#print "covered " . $ref_results->{alignment_coverage} . " " . $ref_results->{length} . " " . ($ref_results->{length}-$ref_results->{alignment_coverage}) . " " . $ref_uncovered . "\n";

#$template->param(REF_ALIGN_PERC => sprintf "%.2f",($ref_results->{alignment_coverage} / $ref_results->{length} * 100));
$template->param(REF_CODEXON => format_number($ref_results->{coding_exon_length}));
#$template->param(REF_CODEXON_PERC => sprintf "%.2f",($ref_results->{coding_exon_length} / $ref_results->{length}* 100));
$template->param(REF_MATCHES => format_number($ref_results->{matches}));
$template->param(REF_MISMATCHES => format_number($ref_results->{mis_matches}));
$template->param(REF_INSERTIONS => format_number($ref_results->{ref_insertions}));
$template->param(REF_UNCOVERED => format_number($ref_results->{uncovered}));


#$template->param(REF_ALIGN_CODEXON_PERC => sprintf "%.2f",($ref_results->{alignment_exon_coverage} / $ref_results->{coding_exon_length} * 100));

my $file_ref_align_pie = $image_dir . "pie_ref_align_" . $mlss_id . ".png";
create_pie_chart($mlss_id,$ref_results->{alignment_coverage}, $ref_results->{length}, $file_ref_align_pie);

my $file_ref_cod_align_pie = $image_dir . "pie_ref_cod_align_" . $mlss_id . ".png";
create_coding_exon_pie_chart($mlss_id,$ref_results->{matches}, $ref_results->{mis_matches}, $ref_results->{ref_insertions}, $ref_results->{uncovered}, $ref_results->{coding_exon_length}, $file_ref_cod_align_pie);

$template->param(REF_ALIGN_PIE => "$file_ref_align_pie");
$template->param(REF_ALIGN_CODEXON_PIE => "$file_ref_cod_align_pie");

my $non_ref_uncovered = $non_ref_results->{length}-$non_ref_results->{alignment_coverage};

$template->param(NON_REF_GENOME_SIZE =>  format_number($non_ref_results->{length}));
$template->param(NON_REF_GENOME_COVERED => format_number($non_ref_results->{alignment_coverage}));
$template->param(NON_REF_GENOME_UNCOVERED => format_number($non_ref_uncovered));

#$template->param(NON_REF_ALIGN_PERC => sprintf "%.2f",($non_ref_results->{alignment_coverage} / $non_ref_results->{length} * 100));
$template->param(NON_REF_CODEXON => format_number($non_ref_results->{coding_exon_length}));

$template->param(NON_REF_MATCHES => format_number($non_ref_results->{matches}));
$template->param(NON_REF_MISMATCHES => format_number($non_ref_results->{mis_matches}));
$template->param(NON_REF_INSERTIONS => format_number($non_ref_results->{ref_insertions}));
$template->param(NON_REF_UNCOVERED => format_number($non_ref_results->{uncovered}));


my $file_non_ref_align_pie = $image_dir . "pie_non_ref_align_" . $mlss_id . ".png";
create_pie_chart($mlss_id,$non_ref_results->{alignment_coverage}, $non_ref_results->{length}, $file_non_ref_align_pie);

my $file_non_ref_cod_align_pie = $image_dir . "pie_non_ref_cod_align_" . $mlss_id . ".png";
create_coding_exon_pie_chart($mlss_id,$non_ref_results->{matches}, $non_ref_results->{mis_matches}, $non_ref_results->{ref_insertions}, $non_ref_results->{uncovered}, $non_ref_results->{coding_exon_length}, $file_non_ref_cod_align_pie);

$template->param(NON_REF_ALIGN_PIE => "$file_non_ref_align_pie");
$template->param(NON_REF_ALIGN_CODEXON_PIE => "$file_non_ref_cod_align_pie");

print $template->output;

#
#Fetch information from the configuration database given a mlss_id
#
sub fetch_input {
    my ($compara_url, $mlss_id) = @_;
    unless (defined $mlss_id) {
	throw("Unable to find statistics without corresponding mlss_id\n");
    }

    unless (defined $compara_url) {
	throw("Must define compara_url");
    }

    my $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url=>$compara_url);
    my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();
    my $mlss = $compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
    
    my $num_blocks = $mlss->get_value_for_tag("num_blocks");
    
    my $results;
    my $ref_results;
    my $non_ref_results;
    $results->{num_blocks} = $num_blocks;
    
    my $ref_species = $mlss->get_value_for_tag("reference_species");
    my $non_ref_species = $mlss->get_value_for_tag("non_reference_species");

    my $ref_genome_db = $genome_db_adaptor->fetch_by_name_assembly($ref_species);
    $ref_results->{name} = $ref_genome_db->name;
    $ref_results->{assembly} = $ref_genome_db->assembly;

    $ref_results->{length} = $mlss->get_value_for_tag("ref_genome_length");
    $ref_results->{alignment_coverage} = $mlss->get_value_for_tag("ref_genome_coverage");
    $ref_results->{coding_exon_length} = $mlss->get_value_for_tag("ref_coding_exon_length");;
    $ref_results->{matches} = $mlss->get_value_for_tag("ref_matches");
    $ref_results->{mis_matches} = $mlss->get_value_for_tag("ref_mis_matches");
    $ref_results->{ref_insertions} = $mlss->get_value_for_tag("ref_insertions");
    $ref_results->{uncovered} = $mlss->get_value_for_tag("ref_uncovered");

    my $non_ref_genome_db = $genome_db_adaptor->fetch_by_name_assembly($non_ref_species);
    $non_ref_results->{name} = $non_ref_genome_db->name;
    $non_ref_results->{assembly} = $non_ref_genome_db->assembly;

    $non_ref_results->{length} = $mlss->get_value_for_tag("non_ref_genome_length");
    $non_ref_results->{alignment_coverage} = $mlss->get_value_for_tag("non_ref_genome_coverage");
    $non_ref_results->{coding_exon_length} = $mlss->get_value_for_tag("non_ref_coding_exon_length");;
    $non_ref_results->{matches} = $mlss->get_value_for_tag("non_ref_matches");
    $non_ref_results->{mis_matches} = $mlss->get_value_for_tag("non_ref_mis_matches");
    $non_ref_results->{ref_insertions} = $mlss->get_value_for_tag("non_ref_insertions");
    $non_ref_results->{uncovered} = $mlss->get_value_for_tag("non_ref_uncovered");

    $pair_aligner_config->{method_link_type} = $mlss->method->type;

    $pair_aligner_config->{ensembl_release} = $mlss->first_release;

    if ($mlss->source eq "ucsc") {
	$pair_aligner_config->{download_url} = $mlss->url;
    }

    my $pairwise_params = $mlss->get_value_for_tag("param");
    if ($mlss->method->type eq "TRANSLATED_BLAT_NET") { 
	unless (defined $pairwise_params) {
	    $tblat_parameters = {};
	} else {
            my @params = split " ", $pairwise_params;
            foreach my $param (@params) {
                my ($p, $v) = split "=", $param;
                $p =~ s/-//;
                $tblat_parameters->{$p} = $v; 
            }
        }
    } else {
	unless (defined $pairwise_params) {
	    $blastz_parameters = {};
	} else {
            my @params = split " ", $pairwise_params;
            foreach my $param (@params) {
                my ($p, $v) = split "=", $param;
                if ($blastz_options->{$p}) {
                    $blastz_parameters->{$p} = $v; 
                } else {
                    $blastz_parameters->{other} .= $param;
                }
            }
        }
    }
    my $ref_common_name;
    if ($urls) {
	$ref_common_name = $reg->get_adaptor($ref_species, "core", "MetaContainer")->list_value_by_key('species.display_name')->[0];
#	$ref_common_name = $reg->get_adaptor($ref_species, "core", "MetaContainer")->get_common_name;
    } else {
	$ref_common_name = $ref_genome_db->db_adaptor->get_MetaContainer->list_value_by_key('species.display_name')->[0];
#	$ref_common_name = $ref_genome_db->db_adaptor->get_MetaContainer->get_common_name;
    }

    my $ref_dna_collection_config;
    my $non_ref_dna_collection_config;
    if ($mlss->get_value_for_tag("ref_dna_collection")) {
        $ref_dna_collection_config = eval $mlss->get_value_for_tag("ref_dna_collection");
    }
    if ($mlss->get_value_for_tag("non_ref_dna_collection")) {
        $non_ref_dna_collection_config = eval $mlss->get_value_for_tag("non_ref_dna_collection");
    }

    $ref_dna_collection_config->{name} = $ref_species;
    $ref_dna_collection_config->{common_name} = $ref_common_name;

    my $non_ref_common_name;
    if ($urls) {
#	$non_ref_common_name = $reg->get_adaptor($non_ref_species, "core", "MetaContainer")->get_common_name;
	$non_ref_common_name = $reg->get_adaptor($non_ref_species, "core", "MetaContainer")->list_value_by_key('species.display_name')->[0];
    } else {
	$non_ref_common_name = $non_ref_genome_db->db_adaptor->get_MetaContainer->list_value_by_key('species.display_name')->[0];
	#$non_ref_common_name = $non_ref_genome_db->db_adaptor->get_MetaContainer->get_common_name;
    }
    $non_ref_dna_collection_config->{name} = $non_ref_species;
    $non_ref_dna_collection_config->{common_name} = $non_ref_common_name;

    return ($results, $ref_results, $non_ref_results, $pair_aligner_config, $blastz_parameters, $tblat_parameters, $ref_dna_collection_config, $non_ref_dna_collection_config);

}

#
#Prettify species name
#
sub pretty_name {
    my ($name) = @_;

    #Upper case first letter
    $name = ucfirst $name;

    #Change "_" to " " 
    $name =~ tr/_/ /;
    return $name;
}

#
#Create and run pie chart R script
#
sub create_pie_chart {
    my ($mlss_id, $num, $length, $filePNG) = @_;

    my $fileR = "/tmp/kb3_pie_" . $mlss_id . "_$$.R";

    my $perc = int(($num/$length*100)+0.5);

    spurt($fileR, join("\n",
            "png(filename=\"$filePNG\", height=200, width =200, units=\"px\")",
            "par(\"mai\"=c(0,0,0,0.3))",
            "align<- c($perc, " . (100-$perc) . ")",
            "labels <- c(\"$perc%\",\"\")",
            "colours <- c(\"grey\", \"white\")",
            "pie(align, labels=labels, clockwise=T, radius=0.9, col=colours)",
            "dev.off()",
        ));

    my $R_cmd = "$R_prog CMD BATCH $fileR";
    unless (system($R_cmd) ==0) {
	throw("$R_cmd failed");
    }
    unlink $fileR;
    return $filePNG;
}

sub create_coding_exon_pie_chart {
    my ($mlss_id, $matches, $mis_matches, $ref_insertions, $uncovered, $coding_exon_length, $filePNG) = @_;

    my $fileR = "/tmp/kb3_pie_" . $mlss_id . "_$$.R";

    my $matches_perc = int(($matches/$coding_exon_length*100)+0.5);
    my $mis_matches_perc = int(($mis_matches/$coding_exon_length*100)+0.5);
    my $ref_insertions_perc = int(($ref_insertions/$coding_exon_length*100)+0.5);
    my $uncovered_perc = int(($uncovered/$coding_exon_length*100)+0.5);

    spurt($fileR, join("\n",
            "png(filename=\"$filePNG\", height=200, width =200, units=\"px\")",
            "par(\"mai\"=c(0,0,0,0.3))",
            "align<- c($matches_perc, $mis_matches_perc, $ref_insertions_perc, $uncovered_perc)",
            "labels <- c(\"$matches_perc%\",\"$mis_matches_perc%\",\"$ref_insertions_perc%\",\"$uncovered_perc%\")",
            "colours <- c(\"red\", \"blue\", \"green\", \"white\")",
            "pie(align, labels=labels, clockwise=T, radius=0.9, col=colours)",
            "dev.off()",
        ));

    my $R_cmd = "$R_prog CMD BATCH $fileR";
    unless (system($R_cmd) ==0) {
	throw("$R_cmd failed");
    }
    unlink $fileR;
    return $filePNG;
}

#
#Create a table to print out the Scoring Matrix
#
sub create_matrix_table {
    my ($file) = @_;

    my $matrix = "\n<table style=\"text-align: right;\" border=\"0\" cellpadding=\"0\" cellspacing=\"5\"> <tbody>\n";
    open(FILE, $file) || die("Couldn't open " . $file);
    while (<FILE>) {
	$matrix .= "<tr>\n";
	my @items = split " ";
	foreach my $item (@items) {
	    $matrix .= "<td>" . $item . "</td>\n";
	}
	$matrix .= "</tr>\n";
    }
    $matrix .= "</tbody></table>\n";
    close(FILE);
    return $matrix;
}
