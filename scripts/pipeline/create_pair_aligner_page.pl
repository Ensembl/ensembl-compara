#!/software/bin/perl -w

=head1 NAME

create_pair_aligner_page.pl

=head1 AUTHORS

Kathryn Beal (kbeal@ebi.ac.uk)

=head1 COPYRIGHT

This modules is part of the Ensembl project http://www.ensembl.org

=head1 DESCRIPTION

This script will output a html document for a pairwise alignment showing the configuration parameters and coverage

=head1 SYNOPSIS

 perl ~/work/projects/tests/test_config/create_pair_aligner_page.pl --config_url mysql://ensadmin:ensembl\@compara1:3306/kb3_pair_aligner_config --mlss_id 455 > pair_aligner_455.html

perl create_pair_aligner_page.pl
   --config_url pair aligner configuration database
   --mlss_id method_link_species_set_id
   [--ensembl_release ensembl schema version]
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

=item B<[--ensembl_release Ensembl version number]>

Ensembl version. Can be used to distinguish between identical method_link_species_set_ids for different Ensembl version.

=item B<[--image_location /path/to/write/image]

Directory to write image files. Default current working directory

=cut

use warnings;
use strict;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Getopt::Long;
use DBI;
use HTML::Template;
use Number::Format qw(:subs :vars);


my $usage = qq{
perl update_config_database.pl
  Getting help:
    [--help]

  Options:
   --config_url mysql://user[:passwd]\@host[:port]/dbname
      Location of the configuration database

   --mlss_id method_link_species_set_id
      Method link species set id of the pairwise alignment

   [--ensembl_release Ensembl version number]

   [--image_location Directory to write image files. Default cwd]

};

my $help;
my $mlss_id;
my $config_url;
my $ensembl_release;
my $image_dir = "./"; #location to write image files
my $R_prog = "/software/R-2.9.0/bin/R ";

my $blastz_template= "/nfs/users/nfs_k/kb3/work/projects/tests/test_config/pair_aligner_blastz_page.tmpl";
my $tblat_template= "/nfs/users/nfs_k/kb3/work/projects/tests/test_config/pair_aligner_tblat_page.tmpl";
my $no_config_template= "/nfs/users/nfs_k/kb3/work/projects/tests/test_config/pair_aligner_no_config_page.tmpl";

my $references = {
       BlastZ => "<a href=\"http://www.genome.org/cgi/content/abstract/13/1/103\">Schwartz S et al., Genome Res.;13(1):103-7</a>, <a href=\"http://www.pnas.org/cgi/content/full/100/20/11484\">Kent WJ et al., Proc Natl Acad Sci U S A., 2003;100(20):11484-9</a>",

       LastZ => "<a href=\"http://www.bx.psu.edu/miller_lab/dist/README.lastz-1.02.00/README.lastz-1.02.00a.html\">LastZ</a>",
       "Translated Blat" => "<a href=\"http://www.genome.org/cgi/content/abstract/12/4/656\">Kent W, Genome Res., 2002;12(4):656-64</a>"};

GetOptions(
           "help" => \$help,
	   "config_url=s" => \$config_url,
	   "mlss|mlss_id|method_link_species_set_id=s" => \$mlss_id,
	   "ensembl_release=s" => \$ensembl_release,
	   "image_location=s" => \$image_dir
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

#Fetch data from the configuration database
my ($alignment_results, $ref_results, $non_ref_results, $pair_aligner_config, $blastz_parameters, $tblat_parameters, $ref_dna_collection_config, $non_ref_dna_collection_config) = fetch_input($config_url, $mlss_id, $ensembl_release);

# open the correct html template
my $template;

if ($pair_aligner_config->{method_link_type} eq "BLASTZ_NET" || 
    $pair_aligner_config->{method_link_type} eq "LASTZ_NET") {

    #Check if have results
    if (defined $blastz_parameters->{O} && defined $blastz_parameters->{E}) {
	#Open blastz/lastz template
	$template = HTML::Template->new(filename => $blastz_template);
    } else {
	$template = HTML::Template->new(filename => $no_config_template);
	if (defined $pair_aligner_config->{download_url} && $pair_aligner_config->{download_url} ne "") {
	    $template->param(CONFIG => "The alignments were downloaded from <a href=\"" . $pair_aligner_config->{download_url} ."\">UCSC.</a>");
	} else {
	    $template->param(CONFIG => "No configuration parameters are available");
	}
    }
} elsif ($pair_aligner_config->{method_link_type} eq "TRANSLATED_BLAT_NET") {

    #Check if have results
    if (defined $tblat_parameters->{minScore} && defined $tblat_parameters->{t} && defined $tblat_parameters->{q}) {
	#Open blastz/lastz template
	$template = HTML::Template->new(filename => $tblat_template);
    } else {
	$template = HTML::Template->new(filename => $no_config_template);
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
$template->param(REFERENCE => $references->{$type});
$template->param(ENSEMBL_RELEASE => $pair_aligner_config->{ensembl_release});

#Set html template variables for configuration parameters
if ($pair_aligner_config->{method_link_type} eq "BLASTZ_NET" || 
    $pair_aligner_config->{method_link_type} eq "LASTZ_NET") {
    if (defined $blastz_parameters->{O} &&
	defined $blastz_parameters->{E}) {
	$template->param(BLASTZ_O => $blastz_parameters->{O});
	$template->param(BLASTZ_E => $blastz_parameters->{E});
	$template->param(BLASTZ_K => $blastz_parameters->{K});
	$template->param(BLASTZ_L => $blastz_parameters->{L});
	$template->param(BLASTZ_H => $blastz_parameters->{H});
	$template->param(BLASTZ_M => $blastz_parameters->{M});
	$template->param(BLASTZ_T => $blastz_parameters->{T});

	if (defined $blastz_parameters->{Q} && $blastz_parameters->{Q} ne "" ) {
	    my $matrix = create_matrix_table($blastz_parameters->{Q});
	    $template->param(BLASTZ_Q => $matrix);
	} else {
	    $template->param(BLASTZ_Q => "Default");
	}
    }
} elsif ($pair_aligner_config->{method_link_type} eq "TRANSLATED_BLAT_NET" &&
	defined $tblat_parameters->{minScore} && 
	defined $tblat_parameters->{t} && 
	defined $tblat_parameters->{q}) {
    
    $template->param(TBLAT_MINSCORE => $tblat_parameters->{minScore});
    $template->param(TBLAT_T => $tblat_parameters->{t});
    $template->param(TBLAT_Q => $tblat_parameters->{q});
    $template->param(TBLAT_MASK => $tblat_parameters->{mask});
    $template->param(TBLAT_QMASK => $tblat_parameters->{qMask});
}

#Set html template variables for results
$template->param(NUM_BLOCKS => $alignment_results->{num_blocks});


$template->param(REF_GENOME_SIZE => format_number($ref_results->{length}));
$template->param(REF_ALIGN => format_number($ref_results->{alignment_coverage}));
#$template->param(REF_ALIGN_PERC => sprintf "%.2f",($ref_results->{alignment_coverage} / $ref_results->{length} * 100));
$template->param(REF_CODEXON => format_number($ref_results->{coding_exon_length}));
#$template->param(REF_CODEXON_PERC => sprintf "%.2f",($ref_results->{coding_exon_length} / $ref_results->{length}* 100));
$template->param(REF_ALIGN_CODEXON => format_number($ref_results->{alignment_exon_coverage}));
#$template->param(REF_ALIGN_CODEXON_PERC => sprintf "%.2f",($ref_results->{alignment_exon_coverage} / $ref_results->{coding_exon_length} * 100));

my $file_ref_align_pie = $image_dir . "pie_ref_align_" . $mlss_id . ".png";
create_pie_chart($mlss_id,$ref_results->{alignment_coverage}, $ref_results->{length}, $file_ref_align_pie);

my $file_ref_cod_align_pie = $image_dir . "pie_ref_cod_align_" . $mlss_id . ".png";
create_pie_chart($mlss_id,$ref_results->{alignment_exon_coverage}, $ref_results->{coding_exon_length}, $file_ref_cod_align_pie);

$template->param(REF_ALIGN_PIE => "$file_ref_align_pie");
$template->param(REF_ALIGN_CODEXON_PIE => "$file_ref_cod_align_pie");

$template->param(NON_REF_GENOME_SIZE =>  format_number($non_ref_results->{length}));
$template->param(NON_REF_ALIGN => format_number($non_ref_results->{alignment_coverage}));
#$template->param(NON_REF_ALIGN_PERC => sprintf "%.2f",($non_ref_results->{alignment_coverage} / $non_ref_results->{length} * 100));
$template->param(NON_REF_CODEXON => format_number($non_ref_results->{coding_exon_length}));
#$template->param(NON_REF_CODEXON_PERC => sprintf "%.2f",($non_ref_results->{coding_exon_length} / $non_ref_results->{length}* 100));
$template->param(NON_REF_ALIGN_CODEXON => format_number($non_ref_results->{alignment_exon_coverage}));
#$template->param(NON_REF_ALIGN_CODEXON_PERC => sprintf "%.2f",($non_ref_results->{alignment_exon_coverage} / $non_ref_results->{coding_exon_length} * 100));

my $file_non_ref_align_pie = $image_dir . "pie_non_ref_align_" . $mlss_id . ".png";
create_pie_chart($mlss_id,$non_ref_results->{alignment_coverage}, $non_ref_results->{length}, $file_non_ref_align_pie);

my $file_non_ref_cod_align_pie = $image_dir . "pie_non_ref_cod_align_" . $mlss_id . ".png";
create_pie_chart($mlss_id,$non_ref_results->{alignment_exon_coverage}, $non_ref_results->{coding_exon_length}, $file_non_ref_cod_align_pie);

$template->param(NON_REF_ALIGN_PIE => "$file_non_ref_align_pie");
$template->param(NON_REF_ALIGN_CODEXON_PIE => "$file_non_ref_cod_align_pie");

print $template->output;

#
#Fetch information from the configuration database given a mlss_id and ensembl_release
#
sub fetch_input {
    my ($config_url, $mlss_id, $ensembl_release) = @_;
    unless (defined $mlss_id) {
	throw("Unable to find statistics without corresponding mlss_id\n");
    }

    unless (defined $config_url) {
	throw("Must define config_url");
    }
    my $dbh = open_db_connection($config_url);
    my $sql;

    #Create query
    if (defined $ensembl_release) {
	$sql = "SELECT pair_aligner_id,num_blocks,ref_genome_db_id, non_ref_genome_db_id,ref_alignment_coverage,ref_alignment_exon_coverage,non_ref_alignment_coverage,non_ref_alignment_exon_coverage FROM pair_aligner_statistics LEFT JOIN pair_aligner_config USING (pair_aligner_id) WHERE pair_aligner_statistics.method_link_species_set_id = ? AND ensembl_release = $ensembl_release";
    } else {
	$sql = "SELECT pair_aligner_id,num_blocks,ref_genome_db_id, non_ref_genome_db_id,ref_alignment_coverage,ref_alignment_exon_coverage,non_ref_alignment_coverage,non_ref_alignment_exon_coverage FROM pair_aligner_statistics WHERE method_link_species_set_id = ?";

    }

    my $sth = $dbh->prepare($sql);
    $sth->execute($mlss_id);
    
    my $results;
    my $ref_results;
    my $non_ref_results;

    #Retrieve pair_aligner_stats
    while (my $row = $sth->fetchrow_arrayref()) {
	$results->{pair_aligner_id} = $row->[0];
	$results->{num_blocks} = $row->[1];
	$ref_results->{genome_db_id} = $row->[2];
	$non_ref_results->{genome_db_id} = $row->[3];
	$ref_results->{alignment_coverage} = $row->[4];
	$ref_results->{alignment_exon_coverage} = $row->[5];
	$non_ref_results->{alignment_coverage} = $row->[6];
	$non_ref_results->{alignment_exon_coverage} = $row->[7];
    }
    
    #Retrieve genome_statistics
    $sql = "SELECT name, assembly, length, coding_exon_length FROM genome_statistics WHERE genome_db_id = ?";
    $sth = $dbh->prepare($sql);
    $sth->execute($ref_results->{genome_db_id});
    
    while (my $row = $sth->fetchrow_arrayref()) {
	$ref_results->{name} = $row->[0];
	$ref_results->{assembly} = $row->[1];
	$ref_results->{length} = $row->[2];
	$ref_results->{coding_exon_length} = $row->[3];
    }	
    
    $sth->execute($non_ref_results->{genome_db_id});
    while (my $row = $sth->fetchrow_arrayref()) {
	$non_ref_results->{name} = $row->[0];
	$non_ref_results->{assembly} = $row->[1];
	$non_ref_results->{length} = $row->[2];
	$non_ref_results->{coding_exon_length} = $row->[3];
    }
    
    #Retrieve pair_aligner_config
    $sql = "SELECT method_link_type, reference_id, non_reference_id, ensembl_release, download_url FROM pair_aligner_config WHERE pair_aligner_id = ?";
    $sth = $dbh->prepare($sql);
    $sth->execute($results->{pair_aligner_id});

    my $pair_aligner_config;
    while (my $row = $sth->fetchrow_arrayref()) {
	$pair_aligner_config->{method_link_type} = $row->[0];
	$pair_aligner_config->{reference_id} = $row->[1];
	$pair_aligner_config->{non_reference_id} = $row->[2];
	$pair_aligner_config->{ensembl_release} = $row->[3];
	$pair_aligner_config->{download_url} = $row->[4];
    }

    #Retrieve blastz_parameters
    $sql = "SELECT T, L, H, K, O, E, M, Q FROM blastz_parameter WHERE pair_aligner_id = ?";
    $sth = $dbh->prepare($sql);
    $sth->execute($results->{pair_aligner_id});
    my $blastz_parameters;
    while (my $row = $sth->fetchrow_arrayref()) {
	$blastz_parameters->{T} = $row->[0];
	$blastz_parameters->{L} = $row->[1];
	$blastz_parameters->{H} = $row->[2];
	$blastz_parameters->{K} = $row->[3];
	$blastz_parameters->{O} = $row->[4];
	$blastz_parameters->{E} = $row->[5];
	$blastz_parameters->{M} = $row->[6];
	$blastz_parameters->{Q} = $row->[7];
    }

    #Retrieve tblat_parameters
    $sql = "SELECT minScore, t, q, mask, qMask FROM tblat_parameter WHERE pair_aligner_id = ?";
    $sth = $dbh->prepare($sql);
    $sth->execute($results->{pair_aligner_id});
    my $tblat_parameters;
    
    #Check if have any parameters ie have a pair_aligner_id
    while (my $row = $sth->fetchrow_arrayref()) {
	$tblat_parameters->{minScore} = $row->[0];
	$tblat_parameters->{t} = $row->[1];
	$tblat_parameters->{q} = $row->[2];
	$tblat_parameters->{mask} = $row->[3];
	$tblat_parameters->{qMask} = $row->[4];
    }

    #Retrieve dna_collection
    my $ref_dna_collection_config;
    my $non_ref_dna_collection_config;

    $sql = "SELECT name, common_name, chunk_size, group_set_size, overlap, masking_options FROM dna_collection WHERE dna_collection_id = ?";
    $sth = $dbh->prepare($sql);
    $sth->execute($pair_aligner_config->{reference_id});

    while (my $row = $sth->fetchrow_arrayref()) {
	$ref_dna_collection_config->{name} = $row->[0];
	$ref_dna_collection_config->{common_name} = $row->[1];
	$ref_dna_collection_config->{chunk_size} = $row->[2];
	$ref_dna_collection_config->{group_set_size} = $row->[3];
	$ref_dna_collection_config->{overlap} = $row->[4];
	$ref_dna_collection_config->{masking_options} = $row->[5];
    }
    
    $sth->execute($pair_aligner_config->{non_reference_id});
    
    while (my $row = $sth->fetchrow_arrayref()) {
	$non_ref_dna_collection_config->{name} = $row->[0];
	$non_ref_dna_collection_config->{common_name} = $row->[1];
	$non_ref_dna_collection_config->{chunk_size} = $row->[1];
	$non_ref_dna_collection_config->{group_set_size} = $row->[2];
	$non_ref_dna_collection_config->{overlap} = $row->[3];
	$non_ref_dna_collection_config->{masking_options} = $row->[4];
    }
    
    $sth->finish;
    
    #Check the collection name and genome_statistics name are the same
    if ($ref_dna_collection_config->{name} ne $ref_results->{name}) {
	throw("dna_collection name " . $ref_dna_collection_config->{name} . " is not the same as the genome_statistics name " . $ref_results->{name} . "\n");
    }

    if ($non_ref_dna_collection_config->{name} ne $non_ref_results->{name}) {
	throw("dna_collection name " . $non_ref_dna_collection_config->{name} . " is not the same as the genome_statistics name " . $non_ref_results->{name} . "\n");
    }

    close_db_connection($dbh);

    return ($results, $ref_results, $non_ref_results, $pair_aligner_config, $blastz_parameters, $tblat_parameters, $ref_dna_collection_config, $non_ref_dna_collection_config);
}

#
#Create database handle from a valid url
#
sub open_db_connection {
    my ($url) = @_;

    my $dbh;
    if ($url =~ /mysql\:\/\/([^\@]+\@)?([^\:\/]+)(\:\d+)?(\/.+)?/ ) {
	my $user_pass = $1;
	my $host      = $2;
	my $port      = $3;
	my $dbname    = $4;
	
	$user_pass =~ s/\@$//;
	my ( $user, $pass ) = $user_pass =~ m/([^\:]+)(\:.+)?/;
	    $pass    =~ s/^\:// if ($pass);
	$port    =~ s/^\:// if ($port);
	$dbname  =~ s/^\/// if ($dbname);
	
	$dbh = DBI->connect("DBI:mysql:$dbname;host=$host;port=$port", $user, $pass, { RaiseError => 1 });
    } else {
	throw("Invalid url $url\n");
    }
    return($dbh);
}

#
#Close database connection
#
sub close_db_connection {
    my ($dbh) = @_;

    $dbh->disconnect;
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

    open FILE, ">$fileR" || die "Unable to open $fileR for writing";
    print FILE "png(filename=\"$filePNG\", height=200, width =200, units=\"px\")\n";
    print FILE "par(\"mai\"=c(0,0,0,0.3))\n";
    print FILE "align<- c($perc, " . (100-$perc) . ")\n";
    print FILE "labels <- c(\"$perc%\",\"\")\n";
    print FILE "colours <- c(\"red\", \"white\")\n";
    print FILE "pie(align, labels=labels, clockwise=T, radius=0.9, col=colours)\n";
    print FILE "dev.off()\n";
    close $fileR;

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
