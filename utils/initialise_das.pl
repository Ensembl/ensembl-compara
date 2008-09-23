#!/usr/local/bin/perl

use strict;
use warnings;

package initialize_das;
# This script
use FindBin qw($Bin);
use Cwd;
use File::Basename;
use Getopt::Long;
use Pod::Usage;
use DBI;
use Data::Dumper;

# --- load libraries needed for reading config ---
use vars qw( $SERVERROOT );
BEGIN{
  $SERVERROOT = dirname( $Bin );

  unshift @INC, "$SERVERROOT/conf";
  unshift @INC, "$SERVERROOT";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

my ($sources_page);
&GetOptions(
  's'  => \$sources_page
);

my $sources = {
  'karyotype' => {
    'master_table' => 'karyotype',
    'name'         => 'Karyotype Bands',
    'query'        => '
  select s.name, t.seq_region_start, t.seq_region_end
    from karyotype t, seq_region s
   where t.seq_region_id = s.seq_region_id',
    'source_id'    => 2,
  },
  'transcript' => {
    'master_table' => 'gene',
    'name'         => 'Transcripts',
    'query'        => '
  select s.name, t.seq_region_start, t.seq_region_end
    from gene t, seq_region s
   where t.seq_region_id = s.seq_region_id',
    'source_id'    => 3,
  },
  'translation' => {
	'master_table' => 'gene',
	'name'         => 'Translation',
	'query'        => '
  select sr.name, g.seq_region_start, g.seq_region_end
    from seq_region sr, gene g, transcript t, translation tr
   where sr.seq_region_id = g.seq_region_id
     and g.gene_id = t.gene_id
     and t.transcript_id = tr.translation_id',
	'source_id'   => 4,
  },
  'cagetags' => {
    'master_table' => 'ditag_feature',
    'name'         => 'CAGETags',
    'query'        => '
  select s.name, t.seq_region_start, t.seq_region_end
    from seq_region s, ditag_feature t, analysis a
   where a.logic_name like "%CAGE%" and t.analysis_id = a.analysis_id and t.seq_region_id = s.seq_region_id',
    'source_id'    => 5,
  },
  'ditags' => {
    'master_table' => 'ditag_feature',
    'name'         => 'DITags',
    'query'        => '
  select s.name, t.seq_region_start, t.seq_region_end
    from seq_region s, ditag_feature t, analysis a
   where a.logic_name not like "%CAGE%" and t.analysis_id = a.analysis_id and t.seq_region_id = s.seq_region_id',
    'source_id'    => 4,
  },
  'prediction_transcript' => {
    'master_table' => 'prediction_transcript',
    'name'         => 'Ab initio predictions',
    'query'        => '
  select s.name, t.seq_region_start, t.seq_region_end
    from prediction_transcript t, seq_region s
   where t.seq_region_id = s.seq_region_id',
    'source_id'    => 6,
  },
};
my @feature_types       = keys %$sources;
my %featuresMasterTable = map { ( $_ => $sources->{$_}{'master_table'} ) } keys %$sources;
my %featuresQuery       = map { ( $_ => $sources->{$_}{'query'}        ) } keys %$sources;
my %sourcesIds          = ('reference'=>1, map { ( $_ => $sources->{$_}{'source_id'} ) } keys %$sources );

# Load modules needed for reading config -------------------------------------
require EnsEMBL::Web::SpeciesDefs; 
my $species_info;
my $species_defs = EnsEMBL::Web::SpeciesDefs->new();
my $sitetype = ucfirst(lc($species_defs->ENSEMBL_SITETYPE)) || 'Ensembl';
my $cdb_info = $species_defs->{_storage}->{Multi}->{databases}->{DATABASE_COMPARA};
my $cdb = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
  -dbname => $cdb_info->{'NAME'},
  -host   => $cdb_info->{'HOST'},
  -port   => $cdb_info->{'PORT'},
  -user   => $cdb_info->{'USER'},
  -driver => $cdb_info->{'DRIVER'},
);

my $ta = $cdb->get_NCBITaxonAdaptor();
my $hash = $species_defs;

my $species = $SiteDefs::ENSEMBL_SPECIES || [];
my $shash;
$| = 1;
foreach my $sp (@$species) {
warn "Parsing species $sp ".gmtime();
  my $search_info = $species_defs->get_config($sp, 'SEARCH_LINKS');
  (my $vsp = $sp) =~ s/\_/ /g;
  $species_info->{$sp}->{'species'}  = $vsp;
  my $snode = $ta->fetch_node_by_name($vsp) or next;
  $species_info->{$sp}->{'taxon_id'} = $snode->taxon_id;

  my $db_info = $species_defs->get_config($sp, 'databases')->{'DATABASE_CORE'};
  my $db = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -species => $sp,
    -dbname  => $db_info->{'NAME'},
    -host    => $db_info->{'HOST'},
    -port    => $db_info->{'PORT'},
    -user    => $db_info->{'USER'},
    -driver  => $db_info->{'DRIVER'},
  );
  my $dbh = $db->dbc->db_handle;
  my $toplevel_slices   = $dbh->selectall_arrayref( q(
  select sr.name   , 
         sr.length ,
         min(a.asm_start) as start,
         max(a.asm_end)   as stop,
         if(isnull(a.asm_seq_region_id),'no','yes') as subparts,
         cs.name
    from (coord_system as cs, seq_region as sr, seq_region_attrib as sra, attrib_type as at) left join
         assembly as a on a.asm_seq_region_id = sr.seq_region_id 
   where sr.seq_region_id = sra.seq_region_id and
         sra.attrib_type_id = at.attrib_type_id and at.code = "toplevel" and cs.coord_system_id = sr.coord_system_id
   group by sr.seq_region_id
  ));
  my $toplevel_example  = $toplevel_slices->[0];

  my $mapmaster = sprintf("%s.%s.reference", $sp, $species_defs->get_config($sp,'ENSEMBL_GOLDEN_PATH'));
  $shash->{$mapmaster}->{mapmaster} = "$SiteDefs::ENSEMBL_BASE_URL/das/$mapmaster";
  $shash->{$mapmaster}->{description} = sprintf("%s Reference server based on %s assembly. Contains %d top level entries.", $sp, $species_defs->get_config($sp,'ENSEMBL_GOLDEN_PATH'), @$toplevel_slices );
# my $sl = $thash{$search_info->{'MAPVIEW1_TEXT'} || $search_info->{'DEFAULT1_TEXT'}} || $toplevel_slices[0];
    #warn Data::Dumper::Dumper(\%thash);

  my $start = $toplevel_example->[2] || 1;
  my $end   = $toplevel_example->[3] || $toplevel_example->[1];
  $shash->{$mapmaster}->{'test_range'} = sprintf("%s:%d,%d", $toplevel_example->[0], $start, $start+99999>$end?$end:$start+99999);

  entry_points( $toplevel_slices, "$SiteDefs::ENSEMBL_BASE_URL/das/$mapmaster/entry_points", "$SERVERROOT/htdocs/das/$mapmaster" );
  foreach my $feature (@feature_types) {
    my $dbn = 'DATABASE_CORE';
    my $table = $featuresMasterTable{$feature};
    my $rv = $species_defs->get_table_size( { -db => $dbn, -table=> $table }, $sp);
    next unless $rv;
    my $sql = $featuresQuery{$feature};
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    my @r = $sth->fetchrow();
#   print STDERR "\t $sp : $feature => Off\n" and next unless @r;
#   print STDERR "\t $sp : $feature : $table => ", $rv || 'Off',  "\n";
#   print STDERR "\t\t\tTEST REGION : ", join('*', @r), "\n";
    next unless @r;
	my $type = $species_defs->get_config($sp,'ENSEMBL_GOLDEN_PATH');
    my $dsn = sprintf("%s.%s.%s", $sp, $type, $feature);
    $shash->{$dsn}->{'test_range'} = sprintf("%s:%s,%s",@r); 
    $shash->{$dsn}->{mapmaster} = "$SiteDefs::ENSEMBL_BASE_URL/das/$mapmaster";
    $shash->{$dsn}->{description} = sprintf("Annotation source for %s %s", $sp, $feature);
	if (   ($sitetype eq 'Vega')
	    && ($feature =~ /^trans/) ) {
		$type .= '-clone';
		$dsn = sprintf("%s.%s.%s", $sp, $type, $feature);
		$shash->{$dsn}->{'test_range'} = sprintf("%s:%s,%s",@r); 
		$shash->{$dsn}->{mapmaster} = "$SiteDefs::ENSEMBL_BASE_URL/das/$mapmaster";
		$shash->{$dsn}->{description} = sprintf("Annotation source (returns clones) for %s %s", $sp, $feature);
	}
  }
}

sources( $shash, "$SERVERROOT/htdocs/das/sources", $sitetype );
dsn(     $shash, "$SERVERROOT/htdocs/das/dsn"     );

print STDERR sprintf("%d sources are active\n", scalar(keys %$shash));
#print STDERR Data::Dumper::Dumper($species_info);

sub entry_points {
  my( $entry_points, $href, $file ) = @_;

  mkdir $file, 0775 unless -e $file;
  open FH, ">$file/entry_points";
  print FH qq(<?xml version="1.0" standalone="no"?>
<?xml-stylesheet type="text/xsl" href="/das/das.xsl"?>
<!DOCTYPE DASEP SYSTEM "http://www.biodas.org/dtd/dasep.dtd">
<DASEP>
  <ENTRY_POINTS href="$href" version="1.0">);
  foreach my $s ( sort {  $a->[5] cmp $b->[5] || $a->[0] cmp $b->[0] } @$entry_points) {
    printf FH qq(
    <SEGMENT type="%s" id="%s" start="%d" stop="%d" orientation="+" subparts="%s">%s</SEGMENT>),
             $s->[5],  $s->[0],1,         $s->[1],                  $s->[4],      $s->[0];
  }
  print FH qq(
  </ENTRY_POINTS>
</DASEP>);
  close FH;
}

sub dsn {
  my( $sources, $file ) = @_;
  open FH, ">$file";
  print FH qq(<?xml version="1.0" standalone="no"?>
<?xml-stylesheet type="text/xsl" href="/das/das.xsl"?>
<!DOCTYPE DASDSN SYSTEM "http://www.biodas.org/dtd/dasdsn.dtd">
<DASDSN>);
  for my $dsn (sort keys %$sources) {
    my $source = $sources->{$dsn};
    print FH qq(
  <DSN href="$SiteDefs::ENSEMBL_BASE_URL/das/dsn">
    <SOURCE id="$dsn"
                >$source->{'name'}</SOURCE>
    <MAPMASTER  >$source->{'mapmaster'}</MAPMASTER>
    <DESCRIPTION>$source->{'description'}</DESCRIPTION>
  </DSN>);
  }
  print FH qq(
</DASDSN>);
  close FH;
}

sub sources {
  my( $sources, $file,$sitetype ) = @_;
  open FH, ">$file";
  my ($day, $month, $year) = (localtime)[3,4,5];
  my $today = sprintf("%04d-%02d-%02d", $year + 1900, $month + 1, $day);
  my $email = ($sitetype eq 'Vega') ? "vega-helpdesk\@sanger.ac.uk" : "helpdesk\@ensembl.org";
  my %taxon_ids = ();
  print FH qq(<?xml version="1.0" encoding="UTF-8" ?>
<?xml-stylesheet type="text/xsl" href="/das/das.xsl"?>
<SOURCES>);
  for my $dsn (sort keys %$sources) {
    my @n = split /\./, $dsn;
    my $species = shift @n;
    (my $vsp = $species) =~ s/\_/ /g;
    my $source = pop @n;
    my $assembly = join('.', @n);
    # Assume the version starts with a number (if it exists)
    # e.g. NCBI36 -> NCBI + 36, Btau_3.1 -> Btau_ + 3.1, GUINEAPIG -> GUINEAPIG + undef
    my ($authority, $version) = $assembly =~ m/^(\D+)(.*)/;
	my $seq_type = $assembly =~ /-clone/ ? 'Clone' : 'Chromosome';
	my $id;
	if ($sitetype eq 'Vega') {
		my $sp = $species;
		$sp =~ s/^(\w)[A-Za-z]*_(\w{3}).*/$1$2/;
		$id = sprintf("VEGA_%s_%s_%s", $sourcesIds{$source} || $source, $sp, $assembly);
	}
	else {
		$id = sprintf("ENSEMBL_%s_%s", $sourcesIds{$source} || $source, $assembly);
	}
    my $capability = $source eq 'reference' ?  qq(
      <CAPABILITY  type="das1:entry_points"
                   query_uri="$SiteDefs::ENSEMBL_BASE_URL/das/$dsn/entry_points" />
      <CAPABILITY  type="das1:sequence"
                   query_uri="$SiteDefs::ENSEMBL_BASE_URL/das/$dsn/sequence"     />) : qq(
      <CAPABILITY  type="das1:stylesheet"  
                   query_uri="$SiteDefs::ENSEMBL_BASE_URL/das/$dsn/stylesheet"   />);
    $capability .= qq(
      <CAPABILITY  type="das1:features"
                   query_uri="$SiteDefs::ENSEMBL_BASE_URL/das/$dsn/features"     />);
    my $description = $sources->{$dsn}{'description'};
    my $test_range  = $sources->{$dsn}{'test_range' };
    $taxon_ids{$vsp} ||= $ta->fetch_node_by_name($vsp)->taxon_id;
	$assembly =~ s/-clone//;
    
    print FH qq( 
  <SOURCE uri="$id" title="$dsn" description="$description">
    <MAINTAINER    email="$email" />
    <VERSION       uri="latest"
                   created="$today">
      <PROPERTY    name="label"
                   value="ENSEMBL" />
      <COORDINATES uri="ensembl_location_toplevel" 
                   taxid="$taxon_ids{$vsp}"
                   source="$seq_type"
                   authority="$authority"
                   version="$version"
                   test_range="$test_range">$assembly,$seq_type,$vsp</COORDINATES>
    $capability
    </VERSION>
  </SOURCE>);
  }
  print FH qq(
</SOURCES>);
  close FH;
}


__END__
           
=head1 NAME
                                                                                
create_das_dsn_page.pl


=head1 DESCRIPTION

A script that generates XML file that effectivly is a response to 
/das/dsn and /das/sources commands to this server. The script just prints the XML to STDOUT.
To create a file use redirection. e.g

./create_das_dsn_page.pl > ../htdocs/das/dsn
./create_das_dsn_page.pl -s > ../htdocs/das/sources


=head1 AUTHOR
                                                                                
[Eugene Kulesha], Ensembl Web Team
Support enquiries: helpdesk@ensembl.org
                                                                                
=head1 COPYRIGHT
                                                                                
See http://www.ensembl.org/info/about/code_licence.html

