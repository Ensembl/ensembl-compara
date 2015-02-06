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

my ($force_update,$check_registry,$site,$xml,$override_authority) = (0,0,'',0);
GetOptions(
  "force",  \$force_update,
  "check",  \$check_registry,
  "site=s", \$site,
  "xml", \$xml,
  "authority=s", \$override_authority, 
);

my $permalink_base = $site || $SiteDefs::ENSEMBL_BASE_URL;

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
   where a.logic_name like "%cage%" and t.analysis_id = a.analysis_id and t.seq_region_id = s.seq_region_id',
    'source_id'    => 5,
  },
  'ditags' => {
    'master_table' => 'ditag_feature',
    'name'         => 'DITags',
    'query'        => '
  select s.name, t.seq_region_start, t.seq_region_end
    from seq_region s, ditag_feature t, analysis a
   where a.logic_name not like "%cage%" and t.analysis_id = a.analysis_id and t.seq_region_id = s.seq_region_id',
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
  'constrained_element' => {
    'master_db' => 'DATABASE_COMPARA',
    'master_table' => 'constrained_element',
    'name'         => 'GERP Constrained elements',
    'query'        => qq{
   SELECT f.name, ce.dnafrag_start, ce.dnafrag_end 
     FROM constrained_element ce, dnafrag f, genome_db g 
     WHERE ce.dnafrag_id = f.dnafrag_id and f.genome_db_id = g.genome_db_id and g.name = ? 
     LIMIT 1 },
    'params' => {
	species => 1,
    },
    'source_id'    => 8,
  },
  'spine' => {
    'master_table' => 'gene',
    'name'         => 'Gene Summary',
    'coord_system' => 'ensembl_gene',
    'query'        => '
  select stable_id
    from gene
    limit 1',
    'source_id'    => 9,
    'multi_species' => 1,
  },
};

my @feature_types       = grep {! $source_types->{$_}->{multi_species}} keys %$source_types; 

my %featuresMasterTable = map { ( $_ => $source_types->{$_}{'master_table'} ) } keys %$source_types;
my %featuresQuery       = map { ( $_ => $source_types->{$_}{'query'}        ) } keys %$source_types;
my %sourcesIds          = ('reference'=>1, map { ( $_ => $source_types->{$_}{'source_id'} ) } keys %$source_types); 

# Load modules needed for reading config -------------------------------------
require EnsEMBL::Web::SpeciesDefs;
my $species_info;
my $species_defs = EnsEMBL::Web::SpeciesDefs->new();
my $das_parser   = Bio::EnsEMBL::ExternalData::DAS::SourceParser->new();
my $sitetype = ucfirst(lc($species_defs->ENSEMBL_SITETYPE)) || 'Ensembl';
#my $docroot = ($sitetype eq 'Vega') ? $SERVERROOT.'/sanger-plugins/vega' : $SERVERROOT; #tried to use this to compartmentalise vega files but have problems with xsl parsing
my $docroot = $SERVERROOT;
my $cdb_info = $species_defs->{_storage}->{MULTI}->{databases}->{DATABASE_COMPARA};
my $cdb = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
  -dbname => $cdb_info->{'NAME'},
  -host   => $cdb_info->{'HOST'},
  -port   => $cdb_info->{'PORT'},
  -user   => $cdb_info->{'USER'},
  -driver => $cdb_info->{'DRIVER'},
);

my $cdbh = $cdb->dbc->db_handle;
my $ta = $cdb->get_NCBITaxonAdaptor();
my $hash = $species_defs;

my $das_coords = _get_das_coords();

my @species = $species_defs->valid_species();

my $shash;
$| = 1;

publish_multi_species_sources() unless $species_defs->ENSEMBL_SITETYPE eq 'Vega';

SPECIES:
foreach my $sp (@species) {
  print STDERR "[INFO]  Parsing species $sp at ".gmtime()."\n";

  my $search_info = $species_defs->get_config($sp, 'SEARCH_LINKS');
  (my $vsp = $sp) =~ s/\_/ /g;
  $species_info->{$sp}->{'species'}  = $vsp;

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
  my $csa = $db->get_CoordSystemAdaptor();

  my $hcs = $csa->fetch_all()->[0];
  my $rank = $hcs->rank;
  die "[FATAL] Cannot find a coordinate system .." unless $hcs;

  my $type = $hcs->version()  || die "[FATAL] Rank $rank coordinate system has no version for $sp";
  my $mapmaster = sprintf("%s.%s.reference", $sp, $type);

  if (-e "$docroot/htdocs/das/$mapmaster/entry_points") {
    if ($force_update) {
      unlink "$docroot/htdocs/das/$mapmaster/entry_points";
    } else {
      print STDERR "[INFO]  Already processed $sp - skipping\n";
      next SPECIES;
    }
  }
  
  unless ($xml) {
  # Must have these coordinates for all species (though we don't create sources for them yet):
  for my $coord_type ('ensembl_gene', 'ensembl_peptide') {
    unless (exists $das_coords->{$sp}{$coord_type}) {
      # Add to the registry and check it came back OK
      my $tmp = _get_das_coords(_coord_system_as_xml($coord_type, '', $sp, $taxid), $coord_type);
      #if (! $check_registry) {
	    #  $tmp->{$sp}{$coord_type} || warn "[FATAL] Unable to create $coord_type $sp coordinates";
      #}
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
         sra.attrib_type_id = at.attrib_type_id and at.code = "toplevel" and cs.name not like 'LRG%'
   group by sr.seq_region_id
  ));

  my $toplevel_example  = $toplevel_slices->[0];
  my %coords = ();
 SLICE:
  for (@$toplevel_slices) {
    # Set up the coordinate system details
    $_->[6] ||= ''; # version
    if (!$coords{$_->[5]}{$_->[6]}) {
	    if ($xml) {
	      my $txml = _coord_system_as_xml(ucfirst($_->[5]), $_->[6], $sp, $taxid), ucfirst($_->[5])." $_->[6]";
	      $coords{$_->[5]}{$_->[6]} = $txml;
	      next;
      }
      my $cs_xml = $das_coords->{$sp}{$_->[5]}{$_->[6]};


      if (!$cs_xml) {
        $_->[6] = $type;
        $cs_xml = $das_coords->{$sp}{$_->[5]}{$_->[6]};
      }
      if (!$cs_xml) {
        # Add to the registry and check it came back OK
        my $tmp = _get_das_coords(_coord_system_as_xml(ucfirst($_->[5]), $_->[6], $sp, $taxid), ucfirst($_->[5])." $_->[6]");
	      next SPECIES if ($check_registry);
        $cs_xml = $tmp->{$sp}{$_->[5]}{$_->[6]};
        if (!$cs_xml) {
          print STDERR "[ERROR] Coordinate system $_->[5] $_->[6] is not in the DAS Registry! Skipping\n";
          next SPECIES;
        }
      }
      my $start = $_->[2] || 1;
      my $end   = $_->[3] || $_->[1];
      my $test_range = sprintf("%s:%d,%d", $_->[0], $start, $start+99999>$end?$end:$start+99999);
      $cs_xml =~ s/test_range=""/test_range="$test_range"/;
      $coords{$_->[5]}{$_->[6]} = $cs_xml;
    }
  }

  $shash->{$mapmaster}->{coords} = \%coords;
  $shash->{$mapmaster}->{mapmaster} = "$permalink_base/das/$mapmaster";
  $shash->{$mapmaster}->{description} = sprintf("%s Reference server based on %s assembly. Contains %d top level entries.", $sp, $type, 0 + @$toplevel_slices );
# my $sl = $thash{$search_info->{'MAPVIEW1_TEXT'} || $search_info->{'DEFAULT1_TEXT'}} || $toplevel_slices[0];
    #warn Data::Dumper::Dumper(\%thash);

  entry_points( $toplevel_slices, "$permalink_base/das/$mapmaster/entry_points", "$docroot/htdocs/das/$mapmaster" );
  foreach my $feature (@feature_types) {
    my $dbn = $source_types->{$feature}->{master_db} || 'DATABASE_CORE';
    my $table = $featuresMasterTable{$feature};
    my $rv = $species_defs->table_info_other( $sp, $dbn, $table );
    my $rows = $rv ? $rv->{'rows'} : 0;

    print STDERR "\t $sp : $feature : $table => ", $rows || 'Off',  "\n";
    next unless $rows || $source_types->{$feature}->{params}->{species};
    my $sql = $featuresQuery{$feature};
    
    my $sth = ($dbn =~ /COMPARA/) ? $cdbh->prepare($sql) : $dbh->prepare($sql);
    my @params = $source_types->{$feature}->{params}->{species} ? ($vsp) : ();

    $sth->execute(@params);
    my @r = $sth->fetchrow();
    print STDERR "\t $sp : $feature : $table => Off (no features)\n" and next unless @r;
    print STDERR "\t $sp : $feature : $table => ", sprintf "%s:%s,%s\n", @r;

    my $dsn = sprintf("%s.%s.%s", $sp, $type, $feature);
    $shash->{$dsn}->{coords} = \%coords;
    $shash->{$dsn}->{mapmaster} = "$permalink_base/das/$mapmaster";
    $shash->{$dsn}->{description} = sprintf("Annotation source for %s %s", $sp, $feature);
    if (   ($sitetype eq 'Vega')
	&& ($feature =~ /^trans/) ) {
      my $vega_type = $type;
      $vega_type .= '-clone';
      $dsn = sprintf("%s.%s.%s", $sp, $vega_type, $feature);
#      print STDERR  "--adding another Vega source for feature $feature - $dsn";
      $shash->{$dsn}->{mapmaster} = "$permalink_base/das/$mapmaster";
      $shash->{$dsn}->{description} = sprintf("Annotation source (returns clones) for %s %s", $sp, $feature);
      $shash->{$dsn}->{coords} = \%coords;
    }
  }
}
if ($check_registry) {
  print STDERR "\n[INFO] Rerun without the -check option to create the xml\n";
  exit;
}

sources( $shash, "$docroot/htdocs/das/sources", $sitetype );
dsn(     $shash, "$docroot/htdocs/das/dsn"     );

print STDERR sprintf("[INFO]  %d sources have been set up\n", scalar(keys %$shash));
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
#  warn "writing". sprintf qq(<SEGMENT type="%s" id="%s" start="%d" stop="%d" orientation="+" subparts="%s">%s</SEGMENT>),$s->[5],$s->[0],1,$s->[1],$s->[4],$s->[0] ;
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
  <DSN href="$permalink_base/das/dsn">
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

#warn Dumper($sources);

  
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
                   query_uri="$permalink_base/das/$dsn/entry_points" />
      <CAPABILITY  type="das1:sequence"
                   query_uri="$permalink_base/das/$dsn/sequence"     />
): qq(      <CAPABILITY  type="das1:stylesheet"  
                   query_uri="$permalink_base/das/$dsn/stylesheet"   />
);
    $capability .= qq(      <CAPABILITY  type="das1:features"
                   query_uri="$permalink_base/das/$dsn/features"     />);
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
      if (my $cs = $NON_GENOMIC_COORDS{$type}{$authority}) {
        if ($cs->name eq $cs_name) {
          goto CREATE;
        }
      } else {
#        print STDERR '[WARN] Skipping $NON_GENOMIC_COORDS{'.$type.'}{'.$authority.'} (Value not defined)'."\n";
      }
    }
  }

  ($authority, $version) = $cs_version =~ m/([^\d]+)([\d\.\w\-]*)/;


  my %reverse_types = map { $TYPE_MAPPINGS{$_} => $_ } keys %TYPE_MAPPINGS;
  my %reverse_auths = map { $AUTHORITY_MAPPINGS{$_} => $_ } keys %AUTHORITY_MAPPINGS;
  
  $type = $reverse_types{$cs_name} || $cs_name;
  $authority = $reverse_auths{$authority} || $authority;
  
  CREATE:
  
  if ($override_authority) {
    $authority = $override_authority;
    $version = $cs_version;
  }
  
  my $xml = $version ? sprintf q(<COORDINATES source="%s" authority="%s" test_range="" uri="" version="%s" taxid="%s">%2$s_%3$s,%1$s,%s</COORDINATES>),
                               $type, $authority, $version, $taxid, $species
                     : sprintf q(<COORDINATES source="%s" authority="%s" taxid="%s">%2$s,%1$s,%s</COORDINATES>),
                               $type, $authority, $taxid, $species;
  return $xml;
}


sub _get_das_coords {
  my ($add_data, $add_name) = @_;
  my $ua = LWP::UserAgent->new(agent => $sitetype);
  $ua->proxy('http', $species_defs->ENSEMBL_WWW_PROXY);
  $ua->no_proxy(@{$species_defs->ENSEMBL_NO_PROXY||[]});

  my $method = 'GET';
  my $req  = HTTP::Request->new($method => 'http://www.dasregistry.org/das/coordinatesystem');
  
  my $resp = $ua->request( $req );

  my $xml = $resp->content;
  $xml =~ s{^\s*(<\?xml.*?>)?(\s*</?DASCOORDINATESYSTEM>\s*)?}{}mix;
  $xml =~ s/<\/DASCOORDINATESYSTEM>//g;
  $xml =~ s/\s*$//mx;
  $xml .= $add_data;

  my %coords;
  for (grep { /^\s*<COORDINATES/ } split m{</COORDINATES>}mx, $xml) {
    next unless $_;
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

sub publish_multi_species_sources {
# Now Multi species sources, e.g EnsemblGene Id etc
    my $sp = $species_defs->ENSEMBL_PRIMARY_SPECIES;

    my $sources_info = $source_types;
    my @feature_types       = grep {$sources_info->{$_}->{multi_species}} keys %$sources_info;

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
    my $meta = $db->get_MetaContainer();
    my $taxid = $meta->get_taxonomy_id();
    (my $vsp = $sp) =~ s/\_/ /g;
  
    foreach my $feature (@feature_types) {
	    print STDERR "[INFO]  Parsing Multi species source * $feature * at ".gmtime()."\n";
	    my $coord_type = $sources_info->{$feature}->{coord_system} or next;
	    unless (exists $das_coords->{$sp}{$coord_type}) {
	      # Add to the registry and check it came back OK
	      my $tmp = _get_das_coords(_coord_system_as_xml($coord_type, '', $sp, $taxid), $coord_type);
	      $tmp->{$sp}{$coord_type} || die "[FATAL] Unable to create $coord_type $sp coordinates";
	    }

	    my $dbn = $sources_info->{$feature}->{master_db} || 'DATABASE_CORE';
	    my $table = $sources_info->{$feature}->{master_table};
	    my $rv = $species_defs->table_info_other( $sp, $dbn, $table );
	    my $rows = $rv ? $rv->{'rows'} : 0;
	
	    print STDERR "\t $sp : $feature : $table => ", $rows || 'Off',  "\n";

	    next unless $rows || $sources_info->{$feature}->{params}->{species};
	    my $sql = $sources_info->{$feature}->{query};
	    my $sth = ($dbn =~ /COMPARA/) ? $cdbh->prepare($sql) : $dbh->prepare($sql);
	    my @params = $sources_info->{$feature}->{params}->{species} ? ($vsp) : ();
	
	    $sth->execute(@params);
	    my @r = $sth->fetchrow();
	    print STDERR "\t $sp : $feature : $table => Off (no features)\n" and next unless @r;
	    print STDERR "\t $sp : $feature : $table => ", join('*', @r), "\n";
	    next unless @r;

	    my %coords = ();
	    # Set up the coordinate system details
	    my $cs_xml = $das_coords->{''}{$coord_type}{''} || next;
	    my $test_range = $r[0];

	    $cs_xml =~ s/test_range=""/test_range="$test_range"/;
	    $coords{$coord_type}{''} = $cs_xml;
	    my $dsn = sprintf("Multi.Ensembl-GeneID.%s", $feature);
	    $shash->{$dsn}->{coords} = \%coords;
	    $shash->{$dsn}->{mapmaster} = $permalink_base;
	    $shash->{$dsn}->{description} = $sources_info->{$feature}->{description} || sprintf("%s Annotation source ", $sources_info->{$feature}->{name});
    }
}



__END__
           
=head1 NAME
                                                                                
initialise_das.pl

=head1 DESCRIPTION

A script that generates XML file that effectivly is a response to 
/das/dsn and /das/sources commands to this server. The script prints the XML to
htdocs/dsn and htdocs/sources.

One recently solved issue is that the script failed to add entries to the DAS
registry for new assemblies. This appears to be fixed but if it reoccurs then 
the 'check' option can be used to report new assemblies and then Jonathan Warren
(jw12) asked to add them to the registry.

./initialise_das.pl

The (optional) --force forces processing of previously generated species
The (optional) --site allows the specification of a different base url, e.g. --site=http://www.ensembl.org

=head1 AUTHOR

                                                                                
[Eugene Kulesha], Ensembl Web Team
[Andy Jenkinson], EMBL-EBI
Support enquiries: helpdesk@ensembl.org
                                                                                
=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

