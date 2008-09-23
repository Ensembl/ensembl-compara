#!/usr/local/bin/perl

use strict;
use FindBin qw($Bin);
use File::Basename qw( dirname );
use Data::Dumper;

use Getopt::Long qw(:config no_ignore_case);
use DBI;
use CGI qw(:standard *table);

# --- load libraries needed for reading config --------------------------------
use vars qw( $SERVERROOT );
BEGIN{
  $SERVERROOT = dirname( $Bin );
  unshift @INC, "$SERVERROOT/conf";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

require EnsEMBL::Web::SpeciesDefs;                  # Loaded at run time
my $SPECIES_DEFS = EnsEMBL::Web::SpeciesDefs->new;
$SPECIES_DEFS || pod2usage("$0: SpeciesDefs config not found");

my %db_info = %{$SPECIES_DEFS->get_config("Homo_sapiens", 'databases')};

# cmdline options
my ($help);
&GetOptions(
            "help"  => \$help,
            );

if(defined $help) {
    die qq(
    Generates a table of ENCODE regions using data from the DATABASE_CORE
    database configured.

    Usage: $0 [options]
    Options:
    -help    = show this message
    );
}

my $db_user = $db_info{DATABASE_CORE}->{USER};
my $db_pass = $db_info{DATABASE_CORE}->{PASS};
my $db_host = $db_info{DATABASE_CORE}->{HOST};
my $db_port = $db_info{DATABASE_CORE}->{PORT};
my $db_name = $db_info{DATABASE_CORE}->{NAME};

# DB connections
my $dbh;

eval {
    my $dsn = "DBI:mysql:database=$db_name;host=$db_host;port=$db_port";
    $dbh = DBI->connect($dsn,$db_user,$db_pass, { 'RaiseError' => 1 } );
};

if($@) {
    print STDERR ( "\t  [WARN] Can't connect to $db_name\n \t  [WARN] $@");
    exit;
}

my $query = qq(
SELECT seq_region.name, 
       misc_feature.seq_region_start, 
       misc_feature.seq_region_end,
       misc_attrib.value, 
       attrib_type.code 
FROM   misc_set, misc_feature_misc_set, misc_feature, 
       misc_attrib, attrib_type, seq_region 
WHERE  misc_set.misc_set_id = misc_feature_misc_set.misc_set_id 
       and misc_feature_misc_set.misc_feature_id = misc_feature.misc_feature_id
       and misc_feature.misc_feature_id = misc_attrib.misc_feature_id 
       and misc_attrib.attrib_type_id = attrib_type.attrib_type_id 
       and misc_feature.seq_region_id = seq_region.seq_region_id 
       and misc_set.code = 'encode'
);

# Get data
my $data = $dbh->selectall_arrayref($query);
$dbh->disconnect;
output_table($data);

exit;




sub output_table {
  my $data = shift;
  my $file = "$SERVERROOT/public-plugins/ensembl/htdocs/Homo_sapiens/ssi/encode_table.html";
  my $contigview = "/Homo_sapiens/contigview?l=";
  my $cytoview = "/Homo_sapiens/cytoview?l=";
  my $mcvurl_part1 = "/Homo_sapiens/multicontigview?l=";
  my $mcvurl_part2 = "&s1=Mus_musculus&s2=Gallus_gallus";

  open (ENCODE_TABLE,  ">$file") or die "Cannot write $file: $!";
  print STDERR "INFO: Writing encode file \'$file\'\n";

  # PRINT
  my $time = localtime;
  print ENCODE_TABLE "<!-- This information is generated using $0 on $time -->\n";
  print ENCODE_TABLE qq(<table class="ss">);
  print ENCODE_TABLE TR(th("Region name"), 
			th("Chr."),
			th("start..end"),
			th("Description"),
			th("Compara"),
		       );
  print ENCODE_TABLE "\n";

  my %regions;
  foreach my $arrays (  @{$data}  ) {
    my ($chr, $start, $end, $value, $code) = @$arrays;

    $regions{"$chr:$start-$end"}{chr}   = $chr;
    $regions{"$chr:$start-$end"}{start} = $start;
    $regions{"$chr:$start-$end"}{end}   = $end;
    $regions{"$chr:$start-$end"}{$code} = $value;
  }

  foreach my $region ( sort {
    $regions{$a}->{chr} <=> $regions{$b}->{chr} 
  } keys %regions ) {

    my $start = $regions{$region}->{start};
    my $end = $regions{$region}->{end};
    my $chr = $regions{$region}->{chr};
    my $url = $end - $start > 1000000 ? $cytoview : $contigview;
    print ENCODE_TABLE TR(
			  td( $regions{$region}->{name} ),
			  td( $chr ),
			  td( a( {-href=>$url.$chr.
				':'.$start."-".$end},
			       "$start..$end")  ),
			  td( $regions{$region}->{description} || "-" ).
			  td(a({-href=>$mcvurl_part1.
				"$chr:$start-$end".
				$mcvurl_part2},
			       "MultiSpecies")  ),
			 );
    print ENCODE_TABLE "\n";
  }
  print ENCODE_TABLE end_table();

}

__END__


=head1 NAME

make_encode_table.pl

=head1 SYNOPSIS

make_encode_table.pl  [options]

Using the default settings or information given when the script is run, this program gets the encode regions from the mysql core database and prints out an HTML table to file 'htdocs/Homo_sapiens/ssi/encode_table.html' with links to contigview.

Options:
   --help

B<-h,--help>
   Prints a brief help message and exits.

=head1 DESCRIPTION

B<This program:>

Prints out the encode table and links to the file public-plugins/ensembl/htdocs/Homo_sapiens/ssi/encode_table.html

Maintained by Fiona Cunningham <fc1@sanger.ac.uk>

=cut

