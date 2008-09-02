package EnsEMBL::Web::ConfigPacker;

use strict;
use warnings;
use EnsEMBL::Web::ConfigPacker_base;
use Bio::EnsEMBL::ExternalData::DAS::SourceParser;
use Data::Dumper;

our @ISA = qw(EnsEMBL::Web::ConfigPacker_base);

sub _munge_databases {
  my $self = shift;
  my %tables = qw(
    core ENSEMBL_DB
    cdna ENSEMBL_CDNA
    vega ENSEMBL_VEGA
    otherfeatures ENSEMBL_OTHERFEATURES
  );
  foreach my $db ( keys %tables ) {
    $self->_summarise_core_tables( $db, $tables{$db} );
  }

  $self->_summarise_variation_db();
  $self->_summarise_funcgen_db();
  $self->_summarise_website_db();
}

sub _munge_das { # creates das.packed...
  my $self = shift;
  $self->_summarise_dasregistry;
}

sub _munge_databases_multi {
  my $self = shift;
  $self->_summarise_website_db_multi(    );
  $self->_summarise_compara_db(    );
  $self->_summarise_ancestral_db(  );
  $self->_summarise_go_db(         );
}

sub _munge_config_tree {
  my $self = shift;
#---------- munge the results obtained from the database queries
#           of the website and the meta tables
  $self->_munge_meta(       );
  $self->_munge_website(    );

#---------- parse the BLAST configuration
  $self->_configure_blast(  );
}

sub _munge_config_tree_multi {
  my $self = shift;
  $self->_munge_website_multi(    );
}


sub _summarise_generic {
  my( $self, $db_name, $dbh ) = @_;
  my $t_aref = $dbh->selectall_arrayref( 'show table status' );
#---------- Table existance and row counts
  foreach my $row ( @$t_aref ) {
    $self->db_details($db_name)->{'tables'}{$row->[0]}{'rows'} = $row->[4];
  }
#---------- Meta coord system table...
  if( $self->_table_exists( $db_name, 'meta_coord' )) {
    $t_aref = $dbh->selectall_arrayref(
      'select table_name,max_length
         from meta_coord'
    );
    foreach my $row ( @$t_aref ) {
      $self->db_details($db_name)->{'tables'}{$row->[0]}{'coord_systems'}{$row->[1]}=$row->[2];
    }
  }
#---------- Meta table (everything except patches)
  if( $self->_table_exists( $db_name, 'meta' ) ) {
    $t_aref  = $dbh->selectall_arrayref(
      'select meta_key,meta_value,meta_id, species_id
         from meta
        where meta_key != "patch"
        order by meta_key, meta_id'
    );
    my $hash = {};
    foreach my $r( @$t_aref) {
      warn "... $r->[3] $r->[0] ... $r->[1]";
      push @{ $hash->{$r->[3]}{$r->[0]}}, $r->[1];
    }
    $self->db_details($db_name)->{'meta_info'} = $hash;
  }
}

sub _summarise_core_tables {
  my $self   = shift;
  my $db_key = shift;
  my $db_name = shift;
  my $dbh    = $self->db_connect( $db_name );
  return unless $dbh;
  push @{ $self->db_tree->{'core_like_databases'} }, $db_name;

  $self->_summarise_generic( $db_name, $dbh );
##
## Grab each of the analyses - will use these in a moment...
##
  my $t_aref = $dbh->selectall_arrayref(
    'select a.analysis_id, a.logic_name,
            ad.display_label, ad.description,
            ad.displayable, ad.web_data
       from analysis a left join analysis_description as ad on a.analysis_id=ad.analysis_id'
  );
   my $analysis = {};
   foreach my $a_aref (@$t_aref) {
    $analysis->{ $a_aref->[0] } = {
      'logic_name'  => $a_aref->[1],
      'name'        => $a_aref->[2],
      'description' => $a_aref->[3],
      'displayable' => $a_aref->[4],
      'web_data'    => $a_aref->[5]?eval($a_aref->[5]):{}
    };
  }
## 
## Let us get analysis information about each feature type...
##
  foreach my $table ( qw(
	dna_align_feature protein_align_feature simple_feature
        protein_feature marker_feature qtl_feature
	repeat_feature ditag_feature oligo_feature
        transcript gene prediction_transcript unmapped_object
  )) {
    my $res_aref = $dbh->selectall_arrayref(
      "select analysis_id,count(*) from $table group by analysis_id"
    );
    foreach my $T ( @$res_aref ) {
      my $a_ref = $analysis->{$T->[0]};
      warn "Missing analysis entry $table - $T->[0]\n" unless $a_ref;
      my $value = {
        'name'  => $a_ref->{'name'},
        'desc'  => $a_ref->{'description'},
        'disp'  => $a_ref->{'displayable'},
        'web'   => $a_ref->{'web_data'},
        'count' => $T->[1]
      };
      $self->db_details($db_name)->{'tables'}{$table}{'analyses'}{$a_ref->{'logic_name'}} = $value;
    }
  }

#---------- Additional queries - by type...

#
# * Check to see if we have any interpro? - not sure why may drop...
#

#
# * Oligos
#
  $t_aref = $dbh->selectall_arrayref(
    'select a.name,count(*) as n
       from oligo_array as a straight_join oligo_probe as p on
            a.oligo_array_id=p.oligo_array_id straight_join oligo_feature f on
            p.oligo_probe_id=f.oligo_probe_id
      group by a.name'
  );
  foreach my $row (@$t_aref) {
    $self->db_details($db_name)->{'tables'}{'oligo_feature'}{'arrays'}{$row->[0]} = $row->[1];
  }
#  
# * Repeats
#
  $t_aref = $dbh->selectall_arrayref(
    'select rf.analysis_id,rc.repeat_type, count(*)
       from repeat_consensus as rc, repeat_feature as rf
      where rc.repeat_consensus_id = rf.repeat_consensus_id
      group by analysis_id, repeat_type'
  );
  foreach my $row (@$t_aref) {
    my $a_ref = $analysis->{$row->[0]};
    $self->db_details($db_name)->{'tables'}{'repeat_feature'}{'analyses'}{$a_ref->{'logic_name'}}{'types'}{$row->[1]} = $row->[2];
  }
#
# * Misc-sets
#
  $t_aref = $dbh->selectall_arrayref(
    'select ms.code, ms.name, ms.description, count(*) as N, ms.max_length
       from misc_set as ms, misc_feature_misc_set as mfms
      where mfms.misc_set_id = ms.misc_set_id
      group by ms.misc_set_id'
  );
  $self->db_details($db_name)->{'tables'}{'misc_feature'}{'sets'} = { map {
    ( $_->[0] => { 'name' => $_->[1], 'desc' => $_->[2], 'count' => $_->[3], 'max_length' => $_->[4] })
  } @$t_aref };

#
# * External-db
#
  my $sth = $dbh->prepare(qq(select * from external_db));
  $sth->execute;
  my $det;
  while (my $hashref = $sth->fetchrow_hashref) {
	  $det->{$hashref->{'external_db_id'}} = $hashref;
  }
  $self->db_details($db_name)->{'external_dbs'} = $det;

#---------- Now for the core only ones.......

  if( $db_name eq 'core' ) {
#
# * Co-ordinate systems..
#

    my $row =  $dbh->selectrow_arrayref(
      'select sr.name, sr.length 
         from seq_region as sr, coord_system as cs 
        where cs.name in( "chromosome", "group" ) and
              cs.coord_system_id = sr.coord_system_id 
        order by sr.length
         desc limit 1'
    );
    if( $row ) {
      $self->db_tree->{'MAX_CHR_NAME'  } = $row->[0];
      $self->db_tree->{'MAX_CHR_LENGTH'} = $row->[1];
    } else {
      $self->db_tree->{'MAX_CHR_NAME'  } = undef;
      $self->db_tree->{'MAX_CHR_LENGTH'} = undef;
    }
  }

#---------------
#
# * Assemblies...
  $t_aref = $dbh->selectall_arrayref(
    'select distinct version from coord_system where version is not null' 
  );
  my @assemblies;
  foreach my $row (@$t_aref) {
    push @assemblies, $row->[0];
  }
  $self->db_tree->{'CURRENT_ASSEMBLIES'} = join(',', @assemblies);

#----------
  $dbh->disconnect();
}

sub _summarise_variation_db {
  my $self    = shift;
  my $db_name = 'ENSEMBL_VARIATION';
  my $dbh     = $self->db_connect( $db_name );
  return unless $dbh;
  $self->_summarise_generic( $db_name, $dbh );
  my $t_aref = $dbh->selectall_arrayref( 'select source_id,name from source' );
#---------- Add in information about the sources from the source table
  my $temp = {map {$_->[0],[$_->[1],0]} @$t_aref};
  foreach my $t (qw(variation variation_synonym)) {
    my $t_aref = $dbh->selectall_arrayref( "select source_id,count(*) from $t group by source_id" );
    foreach (@$t_aref) {
      $temp->{$_->[0]}[1] += $_->[1];
    }
  }
  $self->db_details($db_name)->{'tables'}{'source'}{'counts'} = { map {@$_} values %$temp};

  $dbh->disconnect();
}

sub _summarise_funcgen_db {
  my $self    = shift;
  my $db_name = 'ENSEMBL_FUNCGEN';
  my $dbh     = $self->db_connect( $db_name );
  return unless $dbh;
  $self->_summarise_generic( $db_name, $dbh );
#---------- Currently have to do nothing additional to this!!
  $dbh->disconnect();
}

sub _summarise_website_db {
  ## Get per_species data that is stored in ensembl_website
  my $self    = shift;
  my $db_name = 'ENSEMBL_WEBSITE';
  my $dbh     = $self->db_connect( $db_name );

  ## Assembly history per species
  my $t_aref = $dbh->selectall_arrayref(
    'select r.release_id, rs.assembly_code from species as s, ens_release as r, release_species as rs where s.species_id = rs.species_id and r.release_id = rs.release_id and rs.assembly_code != "" and s.name = "'.$self->species.'"'
  );

  foreach my $row (@$t_aref) {
    $self->db_tree->{'ASSEMBLIES'}{$row->[0]}{$row->[1]} = $row->[2];
  }

  ## Current archive list
  $t_aref = $dbh->selectall_arrayref(
    'select r.release_id, r.archive from ens_release as r, species as s, release_species as rs where s.species_id = rs.species_id and r.release_id = rs.release_id and r.online = "Y" and s.name = "'.$self->species.'"'
  );
  foreach my $row (@$t_aref) {
    $self->db_tree->{'ENSEMBL_ARCHIVES'}{$row->[0]} = $row->[1];
  }
  $dbh->disconnect();
}

#========================================================================#
# The following functions munge the multi-species databases              #
#========================================================================#

sub _summarise_website_db_multi {
  my $self    = shift;
  my $db_name = 'ENSEMBL_WEBSITE';
  my $dbh     = $self->db_connect( $db_name );

  warn "--------------- GETTING HELP --------------------";
  ## Get component-based help
  my $t_aref = $dbh->selectall_arrayref(
    'select help_record_id, data from help_record where type = "component" and status = "live"'
  );
  foreach my $row (@$t_aref) {
    my $data = $row->[1];
    $data =~ s/^\$data = //;
    $data =~ s!\+'!'!g;
    $data = eval ($data);
    warn Dumper($data);
    my $object = $data->{'object'};
    my $action = $data->{'action'};
    $self->db_tree->{'ENSEMBL_HELP'}{$object}{$action} = $row->[0];
  }
  warn Dumper($self->db_tree->{'ENSEMBL_HELP'});
  $dbh->disconnect();
}

sub _summarise_compara_db {
  my $self = shift;
  my $db_name = 'ENSEMBL_COMPARA';
  my $dbh     = $self->db_connect( $db_name );
  return unless $dbh;
  $self->_summarise_generic( $db_name, $dbh );
#---------- Lets first look at all the multiple alignments
  my $res_aref = $dbh->selectall_arrayref( ## We've done the DB hash...So lets get on with the multiple alignment hash;
    'select ml.class, ml.type, gd.name, mlss.name,
            mlss.method_link_species_set_id, ss.species_set_id
	     from method_link ml, method_link_species_set mlss,
            genome_db gd, species_set ss 
      where mlss.method_link_id = ml.method_link_id and
            mlss.species_set_id=ss.species_set_id and 
            ss.genome_db_id = gd.genome_db_id and
            ( ml.class like "GenomicAlign%" or ml.class = "ConservationScore.conservation_score" )
  ');
  my $constrained_elements = { $db_name };
  my %valid_species = map {($_,1)} keys %{$self->full_tree};
  foreach my $row (@$res_aref) {
    my( $class, $type, $species, $name, $id, $species_set_id ) =
      ($row->[0], uc($row->[1]), $row->[2], $row->[3], $row->[4], $row->[5]);
    my $KEY = 'ALIGNMENTS';
    if( $class =~ /ConservationScore/ ||
        $type =~ /CONSERVATION_SCORE/ ) {
      $KEY = "CONSERVATION_SCORES";
      $name = "Conservation scores";
    } elsif( $class =~ /constrained_element/ ||
             $type =~ /CONSTRAINED_ELEMENT/ ) {
      $KEY = "CONSTRAINED_ELEMENTS";
      $constrained_elements->{$species_set_id} = $id;
      $name = "Constrained elements";
    } elsif( $class =~ /tree_alignment/ || $type  =~ /ORTHEUS/ ) {
      unless( exists $self->db_tree->{$db_name}{$KEY}{$id} ) {
        $self->db_tree->{ $db_name }{$KEY}{$id}{'species'}{"Ancestral_sequences"}=1;
      }
    }
    $species =~ tr/ /_/;
    $self->db_tree->{ $db_name }{$KEY}{$id}{'id'}                = $id;
    $self->db_tree->{ $db_name }{$KEY}{$id}{'name'}              = $name;
    $self->db_tree->{ $db_name }{$KEY}{$id}{'type'}              = $type;
    $self->db_tree->{ $db_name }{$KEY}{$id}{'class'}             = $class;
    $self->db_tree->{ $db_name }{$KEY}{$id}{'species_set_id'}    = $species_set_id;
    $self->db_tree->{ $db_name }{$KEY}{$id}{'species'}{$species} = 1;
  }
  foreach my $species_set_id (keys %$constrained_elements) {
    my $constr_elem_id = $constrained_elements->{$species_set_id};
    foreach my $id (keys %{$self->db_tree->{ $db_name }{'ALIGNMENTS'}}) {
      if( $self->db_tree->{ $db_name }{'ALIGNMENTS'}{$id}{'species_set_id'} == $species_set_id) {
        $self->db_tree->{ $db_name }{'ALIGNMENTS'}{$id}{'constrained_element'} = $constr_elem_id;
      }
    }
  }

  $res_aref = $dbh->selectall_arrayref(q(
    select meta_key, meta_value FROM meta where meta_key LIKE "gerp_%"
  ));
  foreach my $row ( @$res_aref ) {
    my ($meta_key, $meta_value) = ($row->[0], $row->[1]);
    my ($conservation_score_id) = $meta_key =~ /gerp_(\d+)/;
    next if (!$conservation_score_id);
    $self->db_tree->{ $db_name }{'ALIGNMENTS'}{$meta_value}{'conservation_score'} = $conservation_score_id;
  }
  my %sections = (
    'ENSEMBL_ORTHOLOGUES' => 'GENE',
    'HOMOLOGOUS_GENE'     => 'GENE',
    'HOMOLOGOUS'          => 'GENE',
  );
# We've done the DB hash... So lets get on with the DNA, SYNTENY and GENE hashes;
  $res_aref = $dbh->selectall_arrayref(qq(
    select ml.type, gd1.name, gd2.name
      from genome_db gd1, genome_db gd2, species_set ss1, species_set ss2,
           method_link ml, method_link_species_set mls1,
           method_link_species_set mls2
     where mls1.method_link_species_set_id = mls2.method_link_species_set_id and
           ml.method_link_id = mls1.method_link_id and
           ml.method_link_id = mls2.method_link_id and
           gd1.genome_db_id != gd2.genome_db_id and
           mls1.species_set_id = ss1.species_set_id and
           mls2.species_set_id = ss2.species_set_id and
           ss1.genome_db_id = gd1.genome_db_id and
           ss2.genome_db_id = gd2.genome_db_id
  ));
  my $self_comparisons = 0;
		  #see if there are any intraspecies alignments (ie a self compara)
  my $res_aref_2 = $dbh->selectall_arrayref(qq(
    select ml.type, gd.name, gd.name, count(*) as count
      from method_link_species_set as mls, method_link as ml,
           species_set as ss, genome_db as gd 
     where mls.species_set_id = ss.species_set_id and
           ss.genome_db_id = gd.genome_db_id and
           mls.method_link_id = ml.method_link_id and
           ml.type not like '%PARALOGUES'
     group by mls.method_link_species_set_id, mls.method_link_id
    having count = 1
  ));
  foreach my $row (@$res_aref_2) {
    $self_comparisons = 1;
    push @$res_aref,$row;
  }
  foreach my $row ( @$res_aref ) {
    my ( $species1, $species2 ) = ( $row->[1], $row->[2] );
    $species1 =~ tr/ /_/;
    $species2 =~ tr/ /_/;
    my $KEY = $sections{uc($row->[0])} || uc( $row->[0] );
    $self->db_tree->{ $db_name }{$KEY}{$species1}{$species2} = $valid_species{ $species2 };
  }
#		  &eprof_dump(\*STDERR);		
  $dbh->disconnect();
}

sub _summarise_ancestral_db {
  my $self = shift;
  my $db_name = 'ENSEMBL_DB';
  my $dbh     = $self->db_connect( $db_name );
  return unless $dbh;
  $self->_summarise_generic( $db_name, $dbh );
  $dbh->disconnect();
}

sub _summarise_go_db {
  my $self = shift;
  my $db_name = 'ENSEMBL_GO';
  my $dbh     = $self->db_connect( $db_name );
  return unless $dbh;
  $self->_summarise_generic( $db_name, $dbh );
  $dbh->disconnect();
}

sub _summarise_dasregistry {
  my $self = shift;
  
  # Registry parsing is lazy so re-use the parser between species'
  my $parser = $self->{'_das_parser'};
  if (!$parser) {
    $parser = Bio::EnsEMBL::ExternalData::DAS::SourceParser->new(
      -location => $self->tree->{'DAS_REGISTRY_URL'},
      -timeout  => $self->tree->{'ENSEMBL_DAS_TIMEOUT'},
      -proxy    => $self->tree->{'ENSEMBL_WWW_PROXY'},
      -noproxy  => $self->tree->{'ENSEMBL_NO_PROXY'},
    );
    $self->{'_das_parser'} = $parser;
  }
  
  # Fetch the sources for the current species
  my %sources = map {
    $_->url => { $_->dsn => $_ }
  } @{ $parser->fetch_Sources(-species => $self->species) };
  
  # The ENSEMBL_INTERNAL_DAS_SOURCES section is a list of enabled DAS sources
  # Then there is a section for each DAS source containing the config
  while (my ($key, $val) = each %{ $self->tree->{'ENSEMBL_INTERNAL_DAS_SOURCES'} }) {
    # Skip disabled sources
    $val || next;
    # Skip sources without any config
    my $cfg = $self->tree->{$key};
    if (!defined $cfg || !ref($cfg)) {
      warn "DAS source $key has no associated configuration";
      next;
    }
    if (!$cfg->{'url'}) {
      warn "DAS source $key has no 'url' property defined";
      next;
    }
    if (!$cfg->{'dsn'}) {
      warn "DAS source $key has no 'dsn' property defined";
      next;
    }
    
    $cfg->{'logic_name'}      = $key;
    
    # Check using the url/dsn if the source is registered
    my $src = $sources{$cfg->{'url'}}{$cfg->{'dsn'}};
    # Doesn't have to be in the registry... unfortunately
    # But if it is, fill in the blanks
    if ($src) {
      $cfg->{'label'}         ||= $src->label;
      $cfg->{'description'}   ||= $src->description;
      $cfg->{'maintainer'}    ||= $src->maintainer;
      $cfg->{'homepage'}      ||= $src->homepage;
      $cfg->{'coords'}        ||= $src->coord_systems;
    }
    
    # Add to the das packed tree as a hash
    $self->das_tree->{'ENSEMBL_INTERNAL_DAS_SOURCES'}{$key} = $cfg;
    # Remove the config from the ini tree
    delete $self->tree->{$key};
  }
  # Remove the list of sources from the ini tree
  delete $self->tree->{'ENSEMBL_INTERNAL_DAS_SOURCES'};
}

sub _meta_info {
  my( $self, $db, $key, $species_id ) = @_;
  $species_id ||= 1;
  return $self->db_details($db)->{'meta_info'}{$species_id}{$key} ||
         $self->db_details($db)->{'meta_info'}{0          }{$key} ||
	 [];
}

sub _munge_meta {
  my $self = shift;

  ## Quick and easy access to species info
  my %keys = qw(
    SPECIES_COMMON_NAME species.ensembl_alias_name
    ASSEMBLY_NAME       assembly.default
    ASSEMBLY_DATE       assembly.date
    GENEBUILD_RELEASE   genebuild.initial_release_date
    GENEBUILD_LATEST    genebuild.last_geneset_update
  );

  foreach my $key ( keys %keys ) {
    $self->tree->{$key} = $self->_meta_info('ENSEMBL_DB',$keys{$key})->[0];
  }

  my $genebuild = $self->_meta_info('ENSEMBL_DB','genebuild.start_date')->[0];
  my @A = split('-', $genebuild);
  my @months = qw(blank Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
  $self->tree->{'GENEBUILD_START'} = $months[$A[1]].$A[0];
  $self->tree->{'GENEBUILD_BY'} = $A[2];

  ## Do species name and group
  my @taxonomy = @{$self->_meta_info('ENSEMBL_DB','species.classification')};
  my $order = $self->tree->{'TAXON_ORDER'};

  $self->tree->{'SPECIES_BIO_NAME'} = $taxonomy[1].' '.$taxonomy[0];

  warn $self->tree->{'SPECIES_BIO_NAME'};
  warn $self->tree->{'ASSEMBLY_NAME'};
  warn $self->tree->{'SPECIES_COMMON_NAME'};
  foreach my $taxon (@taxonomy) {
    foreach my $group (@$order) {
      if ($taxon eq $group) {
        $self->tree->{'SPECIES_GROUP'} = $group;
        last;
      }
    }
    last if $self->tree->{'SPECIES_GROUP'};
  }
}

sub _munge_website {
  my $self = shift;

  ## Release info for ID history etc
  $self->tree->{'ASSEMBLIES'} = $self->db_tree->{'ASSEMBLIES'};

  $self->tree->{'ENSEMBL_ARCHIVES'} = $self->db_tree->{'ENSEMBL_ARCHIVES'};

}

sub _munge_website_multi {
  my $self = shift;

  $self->tree->{'ENSEMBL_HELP'} = $self->db_tree->{'ENSEMBL_HELP'};

}

sub _configure_blast {
}


# sub _munge_multi_meta {
#   my $self = shift;
#   
#   my @months = qw(blank Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
# 
# #warn Dumper($self->db_details('ENSEMBL_DB')->{'meta_info'});
#   my $mhash;
# 
#   foreach my $meta_key (qw(species.ensembl_alias_name assembly.default assembly.date species.classification genebuild.version)) {
#       if (my @meta_values = @{ $self->db_details('ENSEMBL_DB')->{'meta_info'}{$meta_key} || []}) {
# 	  my $i=0;
# 	  while( @meta_values) {
# 	      my $v = shift @meta_values;
# 	      my $sid = shift @meta_values;
# 	      push @{$mhash->{$sid}->{$meta_key}}, $v;
# 	  }
#       }
#   }
# 
#  warn Dumper $mhash;
#   my $order = $self->tree->{'TAXON_ORDER'};
# #  warn "ORDER:", Dumper $order;
# 
#   my @species_list;
#   foreach my $sid (sort keys %$mhash) {
#       my $species_name = $mhash->{$sid}->{'species.ensembl_alias_name'}[0];
##        (my $species_dir = $species_name) =~ s/ /\_/g;
#       $self->tree($species_dir)->{'SPECIES_COMMON_NAME'} = $species_name;
#       $self->tree($species_dir)->{'SPECIES_DBID'} = $sid;
#       push @species_list, $species_name;
#       $self->tree($species_dir)->{'ASSEMBLY_NAME'} = $mhash->{$sid}->{'assembly.default'}[0];
#       $self->tree($species_dir)->{'ASSEMBLY_DATE'} = $mhash->{$sid}->{'assembly.date'}[0];
# 
#       my $genebuild = $mhash->{$sid}->{'genebuild.version'}[0];
#       my @A = split('-', $genebuild);
#       $self->tree($species_dir)->{'GENEBUILD_DATE'} = $months[$A[1]].$A[0];
#       $self->tree($species_dir)->{'GENEBUILD_BY'} = $A[2];
# 
#       ## Do species name and group
#       my @taxonomy = @{$mhash->{$sid}{'species.classification'}||[]};
# #      warn $species_name;
# #      warn Dumper \@taxonomy;
#       $self->tree($species_dir)->{'SPECIES_BIO_NAME'} = $taxonomy[1].' '.$taxonomy[0];
#       foreach my $taxon (@taxonomy) {
# 	  foreach my $group (@$order) {
# 	      if ($taxon eq $group) {
# 		  $self->tree($species_dir)->{'SPECIES_GROUP'} = $group;
# 		  last;
# 	      }
# 	  }
# 	  last if $self->tree($species_dir)->{'SPECIES_GROUP'};
#       }
#       $self->tree->{'SPECIES_LIST'} = \@species_list;
#   }
# }
 
1;
