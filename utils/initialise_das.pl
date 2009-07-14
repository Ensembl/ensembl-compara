#!/usr/local/bin/perl

# This script generates static content (e.g. sources document)
# for DAS. Unfortunately lots of strange things have to happen to map between
# Ensembl and DAS coordinate systems, so this does require some maintenance.

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
use Compress::Zlib;

# --- load libraries needed for reading config ---
use vars qw( $SERVERROOT );
BEGIN{
  $SERVERROOT = dirname( $Bin );

  unshift @INC, "$SERVERROOT/conf";
  unshift @INC, "$SERVERROOT";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
  require Bio::EnsEMBL::ExternalData::DAS::SourceParser;
  import Bio::EnsEMBL::ExternalData::DAS::SourceParser qw(is_genomic %COORD_MAPPINGS %TYPE_MAPPINGS %AUTHORITY_MAPPINGS %NON_GENOMIC_COORDS);
}

my $source_types = {
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
    'source_id'    => 6,
  },
  'prediction_transcript' => {
    'master_table' => 'prediction_transcript',
    'name'         => 'Ab initio predictions',
    'query'        => '
  select s.name, t.seq_region_start, t.seq_region_end
    from prediction_transcript t, seq_region s
   where t.seq_region_id = s.seq_region_id',
    'source_id'    => 7,
  },
};
my @feature_types       = keys %$source_types;
my %featuresMasterTable = map { ( $_ => $source_types->{$_}{'master_table'} ) } keys %$source_types;
my %featuresQuery       = map { ( $_ => $source_types->{$_}{'query'}        ) } keys %$source_types;
my %sourcesIds          = ('reference'=>1, map { ( $_ => $source_types->{$_}{'source_id'} ) } keys %$source_types );

# Load modules needed for reading config -------------------------------------
require EnsEMBL::Web::SpeciesDefs;
my $species_info;
my $species_defs = EnsEMBL::Web::SpeciesDefs->new();
my $das_parser   = Bio::EnsEMBL::ExternalData::DAS::SourceParser->new();
my $sitetype = ucfirst(lc($species_defs->ENSEMBL_SITETYPE)) || 'Ensembl';
my $cdb_info = $species_defs->{_storage}->{MULTI}->{databases}->{DATABASE_COMPARA};
my $cdb = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
  -dbname => $cdb_info->{'NAME'},
  -host   => $cdb_info->{'HOST'},
  -port   => $cdb_info->{'PORT'},
  -user   => $cdb_info->{'USER'},
  -driver => $cdb_info->{'DRIVER'},
);

my $ta = $cdb->get_NCBITaxonAdaptor();
my $hash = $species_defs;

my $das_coords = _get_das_coords();

my $species = $SiteDefs::ENSEMBL_SPECIES || [];
my $shash;
$| = 1;
SPECIES: foreach my $sp (@$species) {
  warn "Parsing species $sp ".gmtime();
  my $search_info = $species_defs->get_config($sp, 'SEARCH_LINKS');
  (my $vsp = $sp) =~ s/\_/ /g;
  $species_info->{$sp}->{'species'}  = $vsp;
  my $type = $species_defs->get_config($sp,'ASSEMBLY_NAME');
  my $mapmaster = sprintf("%s.%s.reference", $sp, $species_defs->get_config($sp,'ASSEMBLY_NAME'));
  
  my $db_info = $species_defs->get_config($sp, 'databases')->{'DATABASE_CORE'};
  my $db = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -species => $sp,
    -dbname  => $db_info->{'NAME'},
    -host    => $db_info->{'HOST'},
    -port    => $db_info->{'PORT'},
    -user    => $db_info->{'USER'},
    -driver  => $db_info->{'DRIVER'},
  );
  my $meta = $db->get_MetaContainer();
  my $taxid = $meta->get_taxonomy_id();
  
  my $skip = 0;
  
  # Registry does not have anything for this species - we can't add it ourselves
  if (!exists $das_coords->{$sp}) {
    warn "Species $sp is not in the DAS Registry!";
    $skip = 1;
  } else {
    # Source doesn't have to exist, but must have these coordinates for all species':
    for my $coord_type ('ensembl_gene', 'ensembl_peptide') {
      unless (exists $das_coords->{$sp}{$coord_type}) {
        my $tmp = _get_das_coords(_coord_system_as_xml($coord_type, '', $sp, $taxid));
        $tmp->{$sp}{$coord_type} || die "Unable to create $coord_type $sp coordinates";
      }
    }
  }

  # Get top level slices from the database
  my $dbh = $db->dbc->db_handle;
  my $toplevel_slices   = $dbh->selectall_arrayref( q(
  select sr.name   , 
         sr.length ,
         min(a.asm_start) as start,
         max(a.asm_end)   as stop,
         if(isnull(a.asm_seq_region_id),'no','yes') as subparts,
         cs.name,
         cs.version
    from (seq_region as sr, seq_region_attrib as sra, attrib_type as at)
    left join
         assembly as a on a.asm_seq_region_id = sr.seq_region_id
    left join
         coord_system as cs on cs.coord_system_id = sr.coord_system_id
   where sr.seq_region_id = sra.seq_region_id and
         sra.attrib_type_id = at.attrib_type_id and at.code = "toplevel"
   group by sr.seq_region_id
  ));
  
  my $toplevel_example  = $toplevel_slices->[0];
  my %coords = ();
  for (@$toplevel_slices) {
    # Set up the coordinate system details
    $_->[6] ||= '';
    if (!$coords{$_->[5]}{$_->[6]}) {
      my $cs_xml = $das_coords->{$sp}{$_->[5]}{$_->[6]};
      if (!$cs_xml) {
        $_->[6] = $type;
        $cs_xml = $das_coords->{$sp}{$_->[5]}{$_->[6]};
      }
      if (!$cs_xml) {
        my $tmp = _get_das_coords(_coord_system_as_xml($_->[5], $_->[6], $sp, $taxid));
        $cs_xml = $tmp->{$sp}{$_->[5]}{$_->[6]};
        if (!$cs_xml) {
          warn "Coordinate system $_->[5] $_->[6] is not in the DAS Registry!";
          $skip = 1;
          $cs_xml = 'bad';
        }
      }
      my $start = $_->[2] || 1;
      my $end   = $_->[3] || $_->[1];
      my $test_range = sprintf("%s:%d,%d", $_->[0], $start, $start+99999>$end?$end:$start+99999);
      $cs_xml =~ s/test_range=""/test_range="$test_range"/;
      $coords{$_->[5]}{$_->[6]} = $cs_xml;
    }
  }
  
  if ($skip) {
    warn "Skipping $sp";
    next SPECIES;
  }

  $shash->{$mapmaster}->{coords} = \%coords;
  $shash->{$mapmaster}->{mapmaster} = "$SiteDefs::ENSEMBL_BASE_URL/das/$mapmaster";
  $shash->{$mapmaster}->{description} = sprintf("%s Reference server based on %s assembly. Contains %d top level entries.", $sp, $species_defs->get_config($sp,'ASSEMBLY_NAME'), 0 + @$toplevel_slices );
# my $sl = $thash{$search_info->{'MAPVIEW1_TEXT'} || $search_info->{'DEFAULT1_TEXT'}} || $toplevel_slices[0];
    #warn Data::Dumper::Dumper(\%thash);

  entry_points( $toplevel_slices, "$SiteDefs::ENSEMBL_BASE_URL/das/$mapmaster/entry_points", "$SERVERROOT/htdocs/das/$mapmaster" );
  foreach my $feature (@feature_types) {
    my $dbn = 'DATABASE_CORE';
    my $table = $featuresMasterTable{$feature};
    my $rv = $species_defs->table_info_other( $sp, $dbn, $table );
    my $rows = $rv ? $rv->{'rows'} : 0;
    next unless $rows;
    my $sql = $featuresQuery{$feature};
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    my @r = $sth->fetchrow();
#   print STDERR "\t $sp : $feature => Off\n" and next unless @r;
#   print STDERR "\t $sp : $feature : $table => ", $rv || 'Off',  "\n";
#   print STDERR "\t\t\tTEST REGION : ", join('*', @r), "\n";
    next unless @r;
    my $dsn = sprintf("%s.%s.%s", $sp, $type, $feature);
    $shash->{$dsn}->{coords} = \%coords;
    $shash->{$dsn}->{mapmaster} = "$SiteDefs::ENSEMBL_BASE_URL/das/$mapmaster";
    $shash->{$dsn}->{description} = sprintf("Annotation source for %s %s", $sp, $feature);
	if (   ($sitetype eq 'Vega')
	    && ($feature =~ /^trans/) ) {
		$type .= '-clone';
		$dsn = sprintf("%s.%s.%s", $sp, $type, $feature);
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
  my $gz = gzopen( "$file/entry_points", 'wb' );

  $gz->gzwrite( qq(<?xml version="1.0" standalone="no"?>
<?xml-stylesheet type="text/xsl" href="/das/das.xsl"?>
<!DOCTYPE DASEP SYSTEM "http://www.biodas.org/dtd/dasep.dtd">
<DASEP>
  <ENTRY_POINTS href="$href" version="1.0">));
  foreach my $s ( sort {  $a->[5] cmp $b->[5] || $a->[0] cmp $b->[0] } @$entry_points) {
    $gz->gzwrite( sprintf qq(
    <SEGMENT type="%s" id="%s" start="%d" stop="%d" orientation="+" subparts="%s">%s</SEGMENT>),
             $s->[5],  $s->[0],1,         $s->[1],                  $s->[4],      $s->[0]
    );
  }
  $gz->gzwrite( qq(
  </ENTRY_POINTS>
</DASEP>) );
  $gz->gzclose();
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
    <SOURCE id="$dsn">$dsn</SOURCE>
    <MAPMASTER>$source->{'mapmaster'}</MAPMASTER>
    <DESCRIPTION>$source->{'description'}</DESCRIPTION>
  </DSN>);
  }
  print FH qq(
</DASDSN>);
  close FH;
}

sub sources {
  my( $sources, $file, $sitetype ) = @_;
  
  open FH, ">$file";
  my ($day, $month, $year) = (localtime)[3,4,5];
  my $today = sprintf("%04d-%02d-%02d", $year + 1900, $month + 1, $day);
  my $email = $SiteDefs::ENSEMBL_HELPDESK_EMAIL;
  
  print FH qq(<?xml version="1.0" encoding="UTF-8" ?>
<?xml-stylesheet type="text/xsl" href="/das/das.xsl"?>
<SOURCES>);

  for my $dsn (sort keys %$sources) {
    
    my ($sp, $assembly, $sourcetype) = $dsn =~ m/^([^\.]+)\.(.+)\.([^\.]+)$/;
    
    my $coordinates = '';  # XML string
    my %coords = %{ $sources->{$dsn}->{coords} };
    for my $cs_name (keys %coords) {
      for my $cs_ver (keys %{$coords{$cs_name}}) {
        $coordinates .= "      $coords{$cs_name}{$cs_ver}\n";
      }
    }

    my $id;
    my $source_type_id = $sourcesIds{$sourcetype} || die "Unknown source type: $sourcetype";
    if ($sitetype eq 'Vega') {
      $sp =~ s/^(\w)[A-Za-z]*_(\w{3}).*/$1$2/;
      $id = sprintf("VEGA_%s_%s_%s", $source_type_id, $sp, $assembly);
    }
    else {
      $id = sprintf("%s_%s_%s", uc $sitetype, $source_type_id, $assembly);
    }
    my $capability = $sourcetype eq 'reference' ?  qq(      <CAPABILITY  type="das1:entry_points"
                   query_uri="$SiteDefs::ENSEMBL_BASE_URL/das/$dsn/entry_points" />
      <CAPABILITY  type="das1:sequence"
                   query_uri="$SiteDefs::ENSEMBL_BASE_URL/das/$dsn/sequence"     />
): qq(      <CAPABILITY  type="das1:stylesheet"  
                   query_uri="$SiteDefs::ENSEMBL_BASE_URL/das/$dsn/stylesheet"   />
);
    $capability .= qq(      <CAPABILITY  type="das1:features"
                   query_uri="$SiteDefs::ENSEMBL_BASE_URL/das/$dsn/features"     />);
    my $description = $sources->{$dsn}{'description'};
    
    print FH qq( 
  <SOURCE uri="$id" title="$dsn" description="$description">
    <MAINTAINER    email="$email" />
    <VERSION       uri="$id"
                   created="$today">
      <PROP name="label" value="ENSEMBL" />
$coordinates$capability
    </VERSION>
  </SOURCE>);
  }
  print FH qq(
</SOURCES>);
  close FH;
}

sub _coord_system_as_xml {
  my ($cs_name, $cs_version, $cs_species, $taxid) = @_;
  
  my ($type, $authority, $version, $species);
  
  my $cs_string = join ':', $cs_name, $cs_version, $cs_species;
  for (keys %COORD_MAPPINGS) {
    $type = $_;
    for (keys %{ $COORD_MAPPINGS{$type} }) {
      $authority = $_;
      for (keys %{ $COORD_MAPPINGS{$type}{$authority} }) {
        $version = $_;
        for (keys %{ $COORD_MAPPINGS{$type}{$authority}{$version} }) {
          $species = $_;
          if ($cs_string eq $COORD_MAPPINGS{$type}{$authority}{$version}{$species}) {
            goto CREATE;
          }
        }
      }
    }
  }
  
  $species = $cs_species;
  $species =~ s/_/ /g;
  $version = undef;
  
  for (keys %NON_GENOMIC_COORDS) {
    $type = $_;
    for (keys %{ $NON_GENOMIC_COORDS{$type} }) {
      $authority = $_;
      my $cs = $NON_GENOMIC_COORDS{$type}{$authority};
      if ($cs->name eq $cs_name) {
        goto CREATE;
      }
    }
  }
  
  ($authority, $version) = $cs_version =~ m/([^\d]+)(.+)/;
  
  my %reverse_types = map { $TYPE_MAPPINGS{$_} => $_ } keys %TYPE_MAPPINGS;
  my %reverse_auths = map { $AUTHORITY_MAPPINGS{$_} => $_ } keys %AUTHORITY_MAPPINGS;
  
  $type = $reverse_types{$cs_name} || $cs_name;
  $authority = $reverse_auths{$authority} || $authority;
  
  CREATE:
  my $xml = $version ? sprintf q(<COORDINATES source="%s" authority="%s" version="%s" taxid="%s">%2$s_%3$s,%1$s,%s</COORDINATES>),
                               $type, $authority, $version, $taxid, $species
                     : sprintf q(<COORDINATES source="%s" authority="%s" taxid="%s">%2$s,%1$s,%s</COORDINATES>),
                               $type, $authority, $taxid, $species;
  return $xml;
}

sub _get_das_coords {
  my ($add_data) = @_;
  my $ua = LWP::UserAgent->new(agent => $sitetype);
  $ua->proxy('http', $species_defs->ENSEMBL_WWW_PROXY);
  $ua->no_proxy(@{$species_defs->ENSEMBL_NO_PROXY||[]});
  my $method = $add_data ? 'POST' : 'GET';
  my $req  = HTTP::Request->new($method => 'http://www.dasregistry.org/das/coordinatesystem');
  
  # If we have XML for a new coordinate system, add it
  if ($add_data) {
    $add_data = qq(<?xml version='1.0' ?>\n<DASCOORDINATESYSTEM>\n  $add_data\n</DASCOORDINATESYSTEM>);
    $req->content($add_data);
    $req->content_length(length $add_data);
  }
  
  my $resp = $ua->request( $req );
  $resp->is_success || die "Unable to retrieve coordinate system list from the DAS Registry: ".$resp->status_line;
  my $xml = $resp->content;
  $xml =~ s{^\s*(<\?xml.*?>)?(\s*</?DASCOORDINATESYSTEM>\s*)?}{}mix;
  $xml =~ s/\s*$//mx;
  
  my %coords;
  for (grep { /^\s*<COORDINATES/ } split m{</COORDINATES>}mx, $xml) {
    $_ =~ s/^\s+//;
    my $cs_xml = "$_</COORDINATES>";
    my ($type) = m/source\s*=\s*"(.*?)"/mx;
    my ($authority) = m/authority\s*=\s*"(.*?)"/mx;
    my ($version) = m/version\s*=\s*"(.*?)"/mx;
    my ($taxid) = m/taxid\s*=\s*"(.*?)"/mx;
    my ($des) = m/>(.*)$/mx;
    my (undef, undef, $species) = split /,/, $des, 3;
    
    $type || die "Unable to parse type from $cs_xml";
    $authority || die "Unable to parse authority from $cs_xml";
    
    my $cs_ob = $das_parser->_parse_coord_system($type, $authority, $version, $species);
    $cs_ob || next;
    
    $coords{$cs_ob->species}{$cs_ob->name}{$cs_ob->version} = $cs_xml;
  }
  
  return \%coords;
}

__END__
           
=head1 NAME
                                                                                
initialise_das.pl

=head1 DESCRIPTION

A script that generates XML file that effectivly is a response to 
/das/dsn and /das/sources commands to this server. The script prints the XML to
htdocs/dsn and htdocs/sources.

./initialise_das.pl

If this script complains about coordinate systems, check that they actually exist
in the DAS registry (http://www.dasregistry.org). If not, request they be added.

=head1 AUTHOR
                                                                                
[Eugene Kulesha], Ensembl Web Team
[Andy Jenkinson], EMBL-EBI
Support enquiries: helpdesk@ensembl.org
                                                                                
=head1 COPYRIGHT
                                                                                
See http://www.ensembl.org/info/about/code_licence.html

