=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::ConfigPacker;

use strict;
use warnings;
no warnings qw(uninitialized);

use base qw(EnsEMBL::Web::ConfigPacker_base);

sub munge {
  my ($self, $func) = @_;
  
  $func .= '_multi' if $self->species eq 'MULTI';
  
  my $munge  = "munge_$func";
  my $modify = "modify_$func";
  
  $self->$munge();
  $self->$modify();
}

sub munge_databases {
  my $self   = shift;
  my @tables = qw(core cdna vega vega_update otherfeatures rnaseq);
  $self->_summarise_core_tables($_, 'DATABASE_' . uc $_) for @tables;
  $self->_summarise_xref_types('DATABASE_' . uc $_) for @tables;
  $self->_summarise_variation_db('variation', 'DATABASE_VARIATION');
  $self->_summarise_variation_db('variation_private', 'DATABASE_VARIATION_PRIVATE');
  $self->_summarise_funcgen_db('funcgen', 'DATABASE_FUNCGEN');
  $self->_compare_update_db('vega_update','DATABASE_VEGA_UPDATE');
}

sub munge_databases_multi {
  my $self = shift;
  $self->_summarise_website_db;
  $self->_summarise_archive_db;
  $self->_summarise_compara_db('compara', 'DATABASE_COMPARA');
  $self->_summarise_compara_db('compara_pan_ensembl', 'DATABASE_COMPARA_PAN_ENSEMBL');
  $self->_summarise_ancestral_db('core', 'DATABASE_CORE');
  $self->_summarise_go_db;
}

sub munge_config_tree {
  my $self = shift;
  
  # munge the results obtained from the database queries of the website and the meta tables
  $self->_munge_meta;
  $self->_munge_variation;
  $self->_munge_website;
}

sub munge_config_tree_multi {
  my $self = shift;
  $self->_munge_website_multi;
  $self->_munge_file_formats;
}

# Implemented in plugins
sub modify_databases         {}
sub modify_databases_multi   {}
sub modify_config_tree       {}
sub modify_config_tree_multi {}

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
## Needs tweaking to work with new ensembl_ontology_xx db, which has no species_id in meta table
  if( $self->_table_exists( $db_name, 'meta' ) ) {
    my $hash = {};

    $t_aref  = $dbh->selectall_arrayref(
      'select meta_key,meta_value,meta_id, species_id
         from meta
        where meta_key != "patch"
        order by meta_key, meta_id'
    );

    foreach my $r( @$t_aref) {
      push @{ $hash->{$r->[3]+0}{$r->[0]}}, $r->[1];
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

## Get chromosomes in order (replacement for array in ini files)
## and also check for presence of LRGs
## Only need to do this once!
  if ($db_name eq 'DATABASE_CORE') {
    my $s_aref = $dbh->selectall_arrayref(
      'select s.name 
      from seq_region s, seq_region_attrib sa, attrib_type a 
      where sa.seq_region_id = s.seq_region_id 
        and sa.attrib_type_id = a.attrib_type_id 
        and a.code = "karyotype_rank" 
      order by abs(sa.value)'
    );
    my $chrs = [];
    foreach my $row (@$s_aref) {
      push @$chrs, $row->[0];
    }
    $self->db_tree->{'ENSEMBL_CHROMOSOMES'} = $chrs;
    $s_aref = $dbh->selectall_arrayref(
        'select count(*) from seq_region where name like "LRG%"'
    );
    if ($s_aref->[0][0] > 0) {
      $self->db_tree->{'HAS_LRG'} = 1;
    }
  }

##
## Grab each of the analyses - will use these in a moment...
##
  my $t_aref = $dbh->selectall_arrayref(
    'select a.analysis_id, lower(a.logic_name), a.created,
            ad.display_label, ad.description,
            ad.displayable, ad.web_data
       from analysis a left join analysis_description as ad on a.analysis_id=ad.analysis_id'
  );
  my $analysis = {};
  foreach my $a_aref (@$t_aref) { 
    ## Strip out "crap" at front and end! probably some q(')s...
    ( my $A = $a_aref->[6] ) =~ s/^[^{]+//;
    $A =~ s/[^}]+$//;
    my $T = eval($A);
    if (ref($T) ne 'HASH') {
      if ($A) {
        warn "Deleting web_data for $db_key:".$a_aref->[1].", check for syntax error";
      }
      $T = {};
    }
    $analysis->{ $a_aref->[0] } = {
      'logic_name'  => $a_aref->[1],
      'name'        => $a_aref->[3],
      'description' => $a_aref->[4],
      'displayable' => $a_aref->[5],
      'web_data'    => $T
    };
  }
  ## Set last repeat mask date whilst we're at it, as needed by BLAST configuration, below
  my $r_aref = $dbh->selectall_arrayref( 
      'select max(date_format( created, "%Y%m%d"))
      from analysis, meta
      where logic_name = lower(meta_value) and meta_key = "repeat.analysis"' 
  );
  my $date;
  foreach my $a_aref (@$r_aref){
    $date = $a_aref->[0];
  } 
  if ($date) { $self->db_tree->{'REPEAT_MASK_DATE'} = $date; } 

  #get website version the db was first released on - needed for Vega BLAST auto configuration
  (my $initial_release) = $dbh->selectrow_array(qq(SELECT meta_value FROM meta WHERE meta_key = 'initial_release.version'));
  if ($initial_release) { $self->db_tree->{'DB_RELEASE_VERSION'} = $initial_release; }

## 
## Let us get analysis information about each feature type...
##
  foreach my $table ( qw(
        dna_align_feature protein_align_feature simple_feature
        protein_feature marker_feature 
        repeat_feature ditag_feature
        transcript gene prediction_transcript unmapped_object
  )) { 
    my $res_aref = $dbh->selectall_arrayref(
      "select analysis_id,count(*) from $table group by analysis_id"
    );
    foreach my $T ( @$res_aref ) {
      my $a_ref = $analysis->{$T->[0]}
        || ( warn("Missing analysis entry $table - $T->[0]\n") && next );
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

    my $df_aref = $dbh->selectall_arrayref(
      "select analysis_id,file_type from data_file group by analysis_id"
      );
  foreach my $T ( @$df_aref ) {
    my $a_ref = $analysis->{$T->[0]}
        || ( warn("Missing analysis entry data_file - $T->[0]\n") && next );
    my $value = {
        'name'    => $a_ref->{'name'},
        'desc'    => $a_ref->{'description'},
        'disp'    => $a_ref->{'displayable'},
        'web'     => $a_ref->{'web_data'},
        'count'   => 1,
        'format'  => lc($T->[1]),
    };
    $self->db_details($db_name)->{'tables'}{'data_file'}{'analyses'}{$a_ref->{'logic_name'}} = $value;
  }


#---------- Additional queries - by type...

#
# * Check to see if we have any interpro? - not sure why may drop...
#

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
  my $hashref;
  while ( my $t =  $sth->fetchrow_hashref) {
    $hashref->{$t->{'external_db_id'}} = $t;
  }
  $self->db_details($db_name)->{'tables'}{'external_db'}{'entries'} = $hashref;

#---------- Now for the core only ones.......

  if( $db_key eq 'core' ) {
#
# * Co-ordinate systems..
#

    my $aref =  $dbh->selectall_arrayref(
      'SELECT sr.name, sr.length FROM seq_region sr 
       INNER JOIN seq_region_attrib sra USING (seq_region_id) 
       INNER JOIN attrib_type at USING (attrib_type_id)
       WHERE at.code = "karyotype_rank"' 
    );
    $self->db_tree->{'MAX_CHR_NAME'  } = undef;
    $self->db_tree->{'MAX_CHR_LENGTH'} = undef;
    my $max_length = 0;
    my $max_name;
    foreach my $row (@$aref) {
      $self->db_tree->{'ALL_CHROMOSOMES'}{$row->[0]} = $row->[1];
      if( $row->[1] > $max_length ) {
        $max_name = $row->[0];
        $max_length = $row->[1];
      }
    }
    $self->db_tree->{'MAX_CHR_NAME'  } = $max_name;
    $self->db_tree->{'MAX_CHR_LENGTH'} = $max_length;

#
# * Ontologies
#
    my $oref =  $dbh->selectall_arrayref(
     'select distinct(db_name) from ontology_xref 
       left join object_xref using(object_xref_id) 
        left join xref using(xref_id) 
         left join external_db using(external_db_id)'
           );
    foreach my $row (@$oref) {
      push @{$self->db_tree->{'SPECIES_ONTOLOGIES'}}, $row->[0] if ($row->[0]);
    }
  }

#---------------
#
# * Assemblies...
# This is a bit ugly, because there's no easy way to sort the assemblies via MySQL
  $t_aref = $dbh->selectall_arrayref(
    'select version, attrib from coord_system where version is not null order by rank' 
  );
  my (%default, %not_default);
  foreach my $row (@$t_aref) {
    my $version = $row->[0];
    my $attrib  = $row->[1];
    if ($attrib =~ /default_version/) {
      $self->db_tree->{'ASSEMBLY_VERSION'} ||= $version; # get top ranked default_version
      $default{$version}++;
    }
    else {
      $not_default{$version}++;
    }
  }
  my @assemblies = keys %default;
  push @assemblies, sort keys %not_default;
  $self->db_tree->{'CURRENT_ASSEMBLIES'} = join(',', @assemblies);
  
#-------------
#
# * Transcript biotypes
# get all possible transcript biotypes
  @{$self->db_details($db_name)->{'tables'}{'transcript'}{'biotypes'}} = map {$_->[0]} @{$dbh->selectall_arrayref(
    'SELECT DISTINCT(biotype) FROM transcript;'
  )};

#----------
  $dbh->disconnect();
}

sub _summarise_xref_types {
  my $self   = shift;
  my $db_name = shift; 
  my $dbh    = $self->db_connect( $db_name ); 
  
  return unless $dbh; 
  my @xref_types;
  my %xrefs_types_hash = %{$self->db_tree->{'XREF_TYPES'}||{}};

  my $aref =  $dbh->selectall_arrayref(qq(
  SELECT distinct(edb.db_display_name) 
    FROM object_xref ox JOIN xref x ON ox.xref_id =x.xref_id JOIN external_db edb ON x.external_db_id = edb.external_db_id
   WHERE edb.type IN ('MISC', 'LIT')
     AND (ox.ensembl_object_type ='Transcript' OR ox.ensembl_object_type ='Translation' )
   GROUP BY edb.db_display_name) );

  foreach my $row (@$aref) {    
    $xrefs_types_hash{$row->[0]} = 1;
  }
  $self->db_tree->{'XREF_TYPES'} = \%xrefs_types_hash;
  $dbh->disconnect();
}

sub _summarise_variation_db {
  my($self,$code,$db_name) = @_;
  my $dbh     = $self->db_connect( $db_name );
  return unless $dbh;
  push @{ $self->db_tree->{'variation_like_databases'} }, $db_name;
  $self->_summarise_generic( $db_name, $dbh );
  
  # get menu config from meta table if it exists
  my $v_conf_aref = $dbh->selectall_arrayref('select meta_value from meta where meta_key = "web_config" order by meta_id asc');
  foreach my $row(@$v_conf_aref) {
    my @values = split(/\#/,$row->[0],-1);
    my ($type,$long_name,$short_name,$key,$parent) = @values;

    push @{$self->db_details($db_name)->{'tables'}{'menu'}}, {
      type       => $type,
      long_name  => $long_name,
      short_name => $short_name,
      key        => $key,
      parent     => $parent
    };
  }
  
  my $t_aref = $dbh->selectall_arrayref( 'select source_id,name,description, if(somatic_status = "somatic", 1, 0), type from source' );
#---------- Add in information about the sources from the source table
  my $temp = {map {$_->[0],[$_->[1],0]} @$t_aref};
  my $temp_description = {map {$_->[1],$_->[2]} @$t_aref};
  my $temp_somatic = { map {$_->[1],$_->[3]} @$t_aref};
  my $temp_type = { map {$_->[1], $_->[4]} @$t_aref};
  foreach my $t (qw(variation variation_synonym)) {
    my $t_aref = $dbh->selectall_arrayref( "select source_id,count(*) from $t group by source_id" );
    foreach (@$t_aref) {
      $temp->{$_->[0]}[1] += $_->[1];
    }
  }
  $self->db_details($db_name)->{'tables'}{'source'}{'counts'} = { map {@$_} values %$temp};
  $self->db_details($db_name)->{'tables'}{'source'}{'descriptions'} = \%$temp_description;
  $self->db_details($db_name)->{'tables'}{'source'}{'somatic'} = \%$temp_somatic;
  $self->db_details($db_name)->{'tables'}{'source'}{'type'} = \%$temp_type;

#---------- Store dbSNP version 
 my $s_aref = $dbh->selectall_arrayref( 'select version from source where name = "dbSNP"' );
 foreach (@$s_aref){
    my ($version) = @$_;
    $self->db_details($db_name)->{'dbSNP_VERSION'} = $version;   
  }

#--------- Does this species have structural variants?
 my $sv_aref = $dbh->selectall_arrayref('select count(*) from structural_variation');
 foreach (@$sv_aref){
    my ($count) = @$_;
    $self->db_details($db_name)->{'STRUCTURAL_VARIANT_COUNT'} = $count;
 }

#---------- Add in information about the display type from the sample table
   my $d_aref = [];
   if ($self->db_details($db_name)->{'tables'}{'sample'}) {
      $d_aref = $dbh->selectall_arrayref( "select name, display from sample where display not like 'UNDISPLAYABLE'" );
   } else {
      my $i_aref = $dbh->selectall_arrayref( "select name, display from individual where display not like 'UNDISPLAYABLE'" );
      push @$d_aref, @$i_aref;
      my $p_aref = $dbh->selectall_arrayref( "select name, display from population where display not like 'UNDISPLAYABLE'" );
      push @$d_aref, @$p_aref; 
   }
   my (@default, $reference, @display, @ld);
   foreach (@$d_aref){
     my  ($name, $type) = @$_;  
     if ($type eq 'REFERENCE') { $reference = $name;}
     elsif ($type eq 'DISPLAYABLE'){ push(@display, $name); }
     elsif ($type eq 'DEFAULT'){ push (@default, $name); }
     elsif ($type eq 'LD'){ push (@ld, $name); } 
   }
   $self->db_details($db_name)->{'tables'}{'sample.reference_strain'} = $reference;
   $self->db_details($db_name)->{'REFERENCE_STRAIN'} = $reference; 
   $self->db_details($db_name)->{'meta_info'}{'sample.default_strain'} = \@default;
   $self->db_details($db_name)->{'DEFAULT_STRAINS'} = \@default;  
   $self->db_details($db_name)->{'meta_info'}{'sample.display_strain'} = \@display;
   $self->db_details($db_name)->{'DISPLAY_STRAINS'} = \@display; 
   $self->db_details($db_name)->{'LD_POPULATIONS'} = \@ld;
#---------- Add in strains contained in read_coverage_collection table
  if ($self->db_details($db_name)->{'tables'}{'read_coverage_collection'}){
    my $r_aref = $dbh->selectall_arrayref(
        'select distinct i.name, i.individual_id
        from individual i, read_coverage_collection r
        where i.individual_id = r.sample_id' 
     );
     my @strains;
     foreach my $a_aref (@$r_aref){
       my $strain = $a_aref->[0] . '_' . $a_aref->[1];
       push (@strains, $strain);
     }
     if (@strains) { $self->db_details($db_name)->{'tables'}{'read_coverage_collection_strains'} = join(',', @strains); } 
  }

#--------- Add in structural variation information
  my $v_aref = $dbh->selectall_arrayref("select s.name, count(*), s.description from structural_variation sv, source s, attrib a where sv.source_id=s.source_id and sv.class_attrib_id=a.attrib_id and a.value!='probe' and sv.somatic=0 group by sv.source_id");
  my %structural_variations;
  my %sv_descriptions;
  foreach (@$v_aref) {
   $structural_variations{$_->[0]} = $_->[1];    
   $sv_descriptions{$_->[0]} = $_->[2];
  }
  $self->db_details($db_name)->{'tables'}{'structural_variation'}{'counts'} = \%structural_variations;
  $self->db_details($db_name)->{'tables'}{'structural_variation'}{'descriptions'} = \%sv_descriptions;

#--------- Add in copy number variant probes information
  my $cnv_aref = $dbh->selectall_arrayref("select s.name, count(*), s.description from structural_variation sv, source s, attrib a where sv.source_id=s.source_id and sv.class_attrib_id=a.attrib_id and a.value='probe' group by sv.source_id");
  my %cnv_probes;
  my %cnv_probes_descriptions;
  foreach (@$cnv_aref) {
   $cnv_probes{$_->[0]} = $_->[1];    
   $cnv_probes_descriptions{$_->[0]} = $_->[2];
  }
  $self->db_details($db_name)->{'tables'}{'structural_variation'}{cnv_probes}{'counts'} = \%cnv_probes;
  $self->db_details($db_name)->{'tables'}{'structural_variation'}{cnv_probes}{'descriptions'} = \%cnv_probes_descriptions;
#--------- Add in somatic structural variation information
  my $som_sv_aref = $dbh->selectall_arrayref("select s.name, count(*), s.description from structural_variation sv, source s, attrib a where sv.source_id=s.source_id and sv.class_attrib_id=a.attrib_id and a.value!='probe' and sv.somatic=1 group by sv.source_id");
  my %somatic_sv;
  my %somatic_sv_descriptions;
  foreach (@$som_sv_aref) {
   $somatic_sv{$_->[0]} = $_->[1];    
   $somatic_sv_descriptions{$_->[0]} = $_->[2];
  }
  $self->db_details($db_name)->{'tables'}{'structural_variation'}{'somatic'}{'counts'} = \%somatic_sv;
  $self->db_details($db_name)->{'tables'}{'structural_variation'}{'somatic'}{'descriptions'} = \%somatic_sv_descriptions;  
#--------- Add in structural variation study information
  my $study_sv_aref = $dbh->selectall_arrayref("select distinct st.name, st.description from structural_variation sv, study st where sv.study_id=st.study_id");
  my %study_sv_descriptions;
  foreach (@$study_sv_aref) {    
   $study_sv_descriptions{$_->[0]} = $_->[1];
  }
  $self->db_details($db_name)->{'tables'}{'structural_variation'}{'study'}{'descriptions'} = \%study_sv_descriptions;    
#--------- Add in Variation set information
  # First get all toplevel sets
  my (%super_sets, %sub_sets, %set_descriptions);

  my $st_aref = $dbh->selectall_arrayref('
    select vs.variation_set_id, vs.name, vs.description, a.value
      from variation_set vs, attrib a
      where not exists (
        select * 
          from variation_set_structure vss
          where vss.variation_set_sub = vs.variation_set_id
        )
        and a.attrib_id = vs.short_name_attrib_id'
  );
  
  # then get subsets foreach toplevel set
  foreach (@$st_aref) {
    my $set_id = $_->[0];
    
    $super_sets{$set_id} = {
      name        => $_->[1],
      description => $_->[2],
      short_name  => $_->[3],
      subsets     => [],
    };
  
  $set_descriptions{$_->[3]} = $_->[2];
    
    my $ss_aref = $dbh->selectall_arrayref("
      select vs.variation_set_id, vs.name, vs.description, a.value 
        from variation_set vs, variation_set_structure vss, attrib a
        where vss.variation_set_sub = vs.variation_set_id 
          and a.attrib_id = vs.short_name_attrib_id
          and vss.variation_set_super = $set_id"  
    );

    foreach my $sub_set (@$ss_aref) {
      push @{$super_sets{$set_id}{'subsets'}}, $sub_set->[0];
      
      $sub_sets{$sub_set->[0]} = {
        name        => $sub_set->[1],
        description => $sub_set->[2],
        short_name  => $sub_set->[3],
      };
    } 
  }
  
  # just get all descriptions
  my $vs_aref = $dbh->selectall_arrayref("
	SELECT a.value, vs.description
	FROM variation_set vs, attrib a
	WHERE vs.short_name_attrib_id = a.attrib_id
  ");
  
  $set_descriptions{$_->[0]} = $_->[1] for @$vs_aref;

  $self->db_details($db_name)->{'tables'}{'variation_set'}{'supersets'}    = \%super_sets;  
  $self->db_details($db_name)->{'tables'}{'variation_set'}{'subsets'}      = \%sub_sets;
  $self->db_details($db_name)->{'tables'}{'variation_set'}{'descriptions'} = \%set_descriptions;
  
#--------- Add in phenotype information
  if ($code !~ /variation_private/i) {
    my $pf_aref = $dbh->selectall_arrayref(qq{
      SELECT pf.type, GROUP_CONCAT(DISTINCT s.name), count(pf.phenotype_feature_id)
      FROM phenotype_feature pf, source s
      WHERE pf.source_id=s.source_id AND pf.is_significant=1 AND pf.type!='SupportingStructuralVariation'
      GROUP BY pf.type
    });

    for(@$pf_aref) {
      $self->db_details($db_name)->{'tables'}{'phenotypes'}{'rows'} += $_->[2];
      $self->db_details($db_name)->{'tables'}{'phenotypes'}{'types'}{$_->[0]}{'count'} = $_->[2];
      $self->db_details($db_name)->{'tables'}{'phenotypes'}{'types'}{$_->[0]}{'sources'} = $_->[1];
    }
  }

#--------- Add in somatic mutation information
  my %somatic_mutations;
	# Somatic source(s)
  my $sm_aref =  $dbh->selectall_arrayref(
    'select distinct(p.description), pf.phenotype_id, s.name 
     from phenotype p, phenotype_feature pf, source s, study st
     where p.phenotype_id=pf.phenotype_id and pf.study_id = st.study_id
     and st.source_id=s.source_id and s.somatic_status = "somatic"'
  );
  foreach (@$sm_aref){ 
    $somatic_mutations{$_->[2]}->{$_->[0]} = $_->[1] ;
  } 
  
	# Mixed source(s)
	my $mx_aref = $dbh->selectall_arrayref(
	  'select distinct(s.name) from variation v, source s 
		 where v.source_id=s.source_id and s.somatic_status = "mixed"'
	);
	foreach (@$mx_aref){ 
    $somatic_mutations{$_->[0]}->{'none'} = 'none' ;
  } 
	
  $self->db_details($db_name)->{'SOMATIC_MUTATIONS'} = \%somatic_mutations;

  ## Do we have SIFT and/or PolyPhen predictions?
  my $prediction_aref = $dbh->selectall_arrayref(
    'select distinct(a.value) from attrib a, protein_function_predictions p where a.attrib_id = p.analysis_attrib_id'
  );
  foreach (@$prediction_aref) {
    if ($_->[0] =~ /sift/i) {
      $self->db_details($db_name)->{'SIFT'} = 1;
    }
    if ($_->[0] =~ /^polyphen/i) {
      $self->db_details($db_name)->{'POLYPHEN'} = 1;
    }
  }
  
  # get possible values from attrib tables
  @{$self->db_details($db_name)->{'SIFT_VALUES'}} = map {$_->[0]} @{$dbh->selectall_arrayref(
    'SELECT a.value FROM attrib a, attrib_type t WHERE a.attrib_type_id = t.attrib_type_id AND t.code = "sift_prediction";'
  )};
  @{$self->db_details($db_name)->{'POLYPHEN_VALUES'}} = map {$_->[0]} @{$dbh->selectall_arrayref(
    'SELECT a.value FROM attrib a, attrib_type t WHERE a.attrib_type_id = t.attrib_type_id AND t.code = "polyphen_prediction";'
  )};

  $dbh->disconnect();
}

sub _summarise_funcgen_db {
  my ($self, $db_key, $db_name) = @_;
  my $dbh = $self->db_connect($db_name);
  
  return unless $dbh;
  
  push @{$self->db_tree->{'funcgen_like_databases'}}, $db_name;
  
  $self->_summarise_generic($db_name, $dbh);
  
  ## Grab each of the analyses - will use these in a moment
  my $t_aref = $dbh->selectall_arrayref(
    'select a.analysis_id, a.logic_name, a.created, ad.display_label, ad.description, ad.displayable, ad.web_data
    from analysis a left join analysis_description as ad on a.analysis_id=ad.analysis_id'
  );
  
  my $analysis = {};
  
  foreach my $a_aref (@$t_aref) {
    my $desc;
    { no warnings; $desc = eval($a_aref->[4]) || $a_aref->[4]; }    
    (my $web_data = $a_aref->[6]) =~ s/^[^{]+//; ## Strip out "crap" at front and end! probably some q(')s
    $web_data     =~ s/[^}]+$//;
    $web_data     = eval($web_data) || {};
    
    $analysis->{$a_aref->[0]} = {
      'logic_name'  => $a_aref->[1],
      'name'        => $a_aref->[3],
      'description' => $desc,
      'displayable' => $a_aref->[5],
      'web_data'    => $web_data
    };
  }

  ## Get analysis information about each feature type
  foreach my $table (qw(probe_feature feature_set result_set)) {
    my $res_aref = $dbh->selectall_arrayref("select analysis_id, count(*) from $table group by analysis_id");
    
    foreach my $T (@$res_aref) {
      my $a_ref = $analysis->{$T->[0]}; #|| ( warn("Missing analysis entry $table - $T->[0]\n") && next );
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

  ## Segmentations are stored differently, now they are in flat-files
  foreach my $a (values %$analysis) {
    next unless $a->{'logic_name'} =~ /(Segway|ChromHMM)/;
    my $type = $1;
    next unless $a->{'name'};
    my $res_cell = $dbh->selectall_arrayref(qq(
      select result_set_id,cell_type_id,display_label,cell_type.name
        from result_set
        join cell_type using (cell_type_id)
        join analysis using (analysis_id)
       where logic_name = ?),undef,$a->{'logic_name'});
    foreach my $C (@$res_cell) {
      my $key = $a->{'logic_name'}.':'.$C->[3];
      my $value = {
        name => qq($C->[2] Regulatory Segmentation ($type)),
        desc => qq($C->[2] <a href="/info/genome/funcgen/regulatory_segmentation.html">$type</a> segmentation state analysis"),
        disp => $a->{'displayable'},
        'web' => {
          celltype => $C->[1],
          celltypename => $C->[2],
          anntype => $type,
          'colourset' => 'fg_segmentation_features',
          'display' => 'off',
          'key' => "seg_$key",
          'type' => 'fg_segmentation_features'
        },
        count => 1,
      };
      $self->db_details($db_name)->{'tables'}{'segmentation'}{"$key$a->{'logic_name'}"} = $value;
    }
  }  

###
### Store the external feature sets available for each species
###
  my @feature_sets;
  my $f_aref = $dbh->selectall_arrayref(
    "select name
      from feature_set
      where type = 'external'"
  );
  foreach my $F ( @$f_aref ){ push (@feature_sets, $F->[0]); }  
  $self->db_tree->{'databases'}{'DATABASE_FUNCGEN'}{'FEATURE_SETS'} = \@feature_sets;


#---------- Additional queries - by type...

#
# * Oligos
#
#  $t_aref = $dbh->selectall_arrayref(
#    'select a.vendor, a.name,count(*)
#       from array as a, array_chip as c straight_join probe as p on
#            c.array_chip_id=p.array_chip_id straight_join probe_feature f on
#            p.probe_id=f.probe_id where a.name = c.name
#      group by a.name'
#  );

  $t_aref = $dbh->selectall_arrayref(
    'select a.vendor, a.name, a.array_id  
       from array a, array_chip c, status s, status_name sn where  sn.name="DISPLAYABLE" 
       and sn.status_name_id=s.status_name_id and s.table_name="array" and s.table_id=a.array_id 
       and a.array_id=c.array_id
    '       
  );
  my $sth = $dbh->prepare(
    'select pf.probe_feature_id
       from array_chip ac, probe p, probe_feature pf, seq_region sr, coord_system cs
       where ac.array_chip_id=p.array_chip_id and p.probe_id=pf.probe_id  
       and pf.seq_region_id=sr.seq_region_id and sr.coord_system_id=cs.coord_system_id 
       and cs.is_current=1 and ac.array_id = ?
       limit 1 
    '
  );
  foreach my $row (@$t_aref) {
    my $array_name = $row->[0] .':'. $row->[1];
    $sth->bind_param(1, $row->[2]);
    $sth->execute;
    my $count = $sth->fetchrow_array();# warn $array_name ." ". $count;
    if( exists $self->db_details($db_name)->{'tables'}{'oligo_feature'}{'arrays'}{$array_name} ) {
      warn "FOUND";
    }
    $self->db_details($db_name)->{'tables'}{'oligo_feature'}{'arrays'}{$array_name} = $count ? 1 : 0;
  }
  $sth->finish;
#
# * functional genomics tracks
#

  $f_aref = $dbh->selectall_arrayref(
    'select ft.name, ct.name 
       from supporting_set ss, data_set ds, feature_set fs, feature_type ft, cell_type ct  
       where ds.data_set_id=ss.data_set_id and ds.name="RegulatoryFeatures" 
       and fs.feature_set_id = ss.supporting_set_id and fs.feature_type_id=ft.feature_type_id 
       and fs.cell_type_id=ct.cell_type_id 
       order by ft.name;
    '
  );   
  foreach my $row (@$f_aref) {
    my $feature_type_key =  $row->[0] .':'. $row->[1];
    $self->db_details($db_name)->{'tables'}{'feature_type'}{'analyses'}{$feature_type_key} = 2;   
  }

  my $c_aref =  $dbh->selectall_arrayref(
    'select  ct.name, ct.cell_type_id, ct.display_label
       from  cell_type ct, feature_set fs  
       where  fs.type="regulatory" and ct.cell_type_id=fs.cell_type_id 
    group by  ct.name order by ct.name'
  );
  foreach my $row (@$c_aref) {
    my $cell_type_key =  $row->[0] .':'. $row->[1];
    $self->db_details($db_name)->{'tables'}{'cell_type'}{'ids'}{$cell_type_key} = 2;
    $self->db_details($db_name)->{'tables'}{'cell_type'}{'names'}{$cell_type_key} = $row->[2];
  }

  foreach my $row (@{$dbh->selectall_arrayref(qq(
      select rs.result_set_id, a.display_label, a.description, c.name, 
             IF(min(g.is_project) = 0 or count(g.name)>1,null,min(g.name))
        from result_set rs
        join analysis_description a using (analysis_id)
        join cell_type c using (cell_type_id)
        join experiment using (cell_type_id)
        join experimental_group g using (experimental_group_id)
       where feature_class = 'dna_methylation'
    group by rs.result_set_id;
  ))}) {
    my ($id,$a_name,$a_desc,$c_desc,$group) = @$row;
    
    my $name = "$c_desc $a_name";
    $name .= " $group" if $group;
    my $desc = "$c_desc cell line: $a_desc";
    $desc .= " ($group group)." if $group;    
    $self->db_details($db_name)->{'tables'}{'methylation'}{$id} = {
      name => $name,
      description => $desc
    };
  }

  my $ft_aref =  $dbh->selectall_arrayref(
    'select ft.name, ft.feature_type_id from feature_type ft, feature_set fs, data_set ds, feature_set fs1, supporting_set ss 
      where fs1.type="regulatory" and fs1.feature_set_id=ds.feature_set_id and ds.data_set_id=ss.data_set_id 
        and ss.type="feature" and ss.supporting_set_id=fs.feature_set_id and fs.feature_type_id=ft.feature_type_id 
   group by ft.name order by ft.name'
  );
  foreach my $row (@$ft_aref) {
    my $feature_type_key =  $row->[0] .':'. $row->[1];
    $self->db_details($db_name)->{'tables'}{'feature_type'}{'ids'}{$feature_type_key} = 2;
  }

  my $rs_aref = $dbh->selectall_arrayref(
    'select name, string 
       from regbuild_string 
      where name like "%regbuild%" and 
            name like "%ids"'
  );
  foreach my $row (@$rs_aref ){
    my ($regbuild_name, $regbuild_string) = @$row; 
    $regbuild_name =~s/regbuild\.//;
    $regbuild_name =~ /^(.*)\.(.*?)$/;
    my @key_info = ($1,$2);
    my %data;  
    my @ids = split(/\,/,$regbuild_string);
    my $sth = $dbh->prepare(
          'select feature_type_id
             from feature_set
            where feature_set_id = ?'
    );
    foreach (@ids){
      if($key_info[1] =~/focus/){
        my $feature_set_id = $_;
        $sth->bind_param(1, $feature_set_id);
        $sth->execute;
        my ($feature_type_id)= $sth->fetchrow_array;
        $data{$feature_type_id} = $_;
      }
      else {
        $data{$_} = 1;
      }
      $sth->finish;
    } 
    $self->db_details($db_name)->{'tables'}{'regbuild_string'}{$key_info[1]}{$key_info[0]} = \%data;
  }
  $dbh->disconnect();
}

sub _compare_update_db {
  my $self    = shift;
  my $db_key  = shift;
  my $db_name = shift;
  my $dbh     = $self->db_connect( $db_name );
  return unless $dbh;
  my $genes;
  my $update_genes = $dbh->selectall_arrayref(
    'select x.display_label, edb.db_name, g.stable_id, g.modified_date, g.biotype, sr.name, g.seq_region_start, g.seq_region_end, g.seq_region_strand
      from seq_region sr, gene g, xref x, external_db edb
     where sr.seq_region_id = g.seq_region_id
       and g.display_xref_id = x.xref_id
       and x.external_db_id = edb.external_db_id
  order by g.stable_id desc
');
  my $core_dbh  = $self->db_connect( 'DATABASE_CORE' );
  my %core_genes;
  foreach my $core_gene (@{$core_dbh->selectall_arrayref('select stable_id from gene')}) {
    $core_genes{$core_gene->[0]}++;
  }
  foreach my $update_gene (@$update_genes) {
    my ($display_label, $source, $stable_id, $modified_date, $biotype, $sr_name, $sr_start, $sr_end, $sr_strand) = @$update_gene;
    my $status =  $core_genes{$stable_id} ? 'updated' : 'new';
    my ($update_date, $update_time) = split ' ', $modified_date;
    my $pos = "$sr_name:$sr_start-$sr_end:$sr_strand";
    push @$genes, {
      'stable_id'   => $stable_id,
      'name'        => $display_label,
      'update_date' => $update_date,
      'biotype'     => $biotype,
      'chr'         => $sr_name,
      'location'    => "$sr_start-$sr_end",
      'pos'         => $pos,
      'status'      => $status,
    };
  }
  $self->db_tree->{'UPDATE_GENES'} = $genes;
}

#========================================================================#
# The following functions munge the multi-species databases              #
#========================================================================#

sub _summarise_website_db {
  my $self    = shift;
  my $db_name = 'DATABASE_WEBSITE';
  my $dbh     = $self->db_connect( $db_name );

  ## Get component-based help
  my $t_aref = $dbh->selectall_arrayref(
    'select hl.page_url, hl.help_record_id from help_record as hr, help_link as hl where hr.help_record_id = hl.help_record_id and status = "live"'
  );
  foreach my $row (@$t_aref) {
    $self->db_tree->{'ENSEMBL_HELP'}{$row->[0]} = $row->[1];
  }

  ## Get glossary
  $t_aref = $dbh->selectall_arrayref(
    'select data from help_record where type = "glossary" and status = "live"'
  );
  foreach my $row (@$t_aref) {
    my $entry = eval($row->[0]);
    $self->db_tree->{'ENSEMBL_GLOSSARY'}{$entry->{'word'}} = $entry->{'meaning'}; 
  }

  ## Get attrib text lookup
  $t_aref = $dbh->selectall_arrayref(
    'select data from help_record where type = "lookup" and status = "live"'
  );
  foreach my $row (@$t_aref) {
    my $entry = eval($row->[0]);
    $self->db_tree->{'TEXT_LOOKUP'}{$entry->{'word'}} = $entry->{'meaning'}; 
  }


  $dbh->disconnect();
}

sub _summarise_archive_db {
  my $self    = shift;
  my $db_name = 'DATABASE_ARCHIVE';
  my $dbh     = $self->db_connect( $db_name );
  return unless $dbh;

  my $t_aref = $dbh->selectall_arrayref(
    'select s.name, r.release_id, rs.assembly_version, rs.initial_release, rs.last_geneset
       from species as s, ens_release as r, release_species as rs
      where s.species_id =rs.species_id and r.release_id =rs.release_id
       and rs.assembly_version != ""'
  );
  foreach my $row ( @$t_aref ) {
    my @A = @$row;
    $self->db_tree->{'ASSEMBLIES'}->{$row->[0]}{$row->[1]}=$row->[2];
  }

  $t_aref = $dbh->selectall_arrayref('select name, common_name, code, vega from species');
  foreach my $row ( @$t_aref ) {
    $self->db_tree->{'ALL_WEB_SPECIES'}{$row->[0]}    = 1;
    $self->db_tree->{'ALL_WEB_SPECIES'}{lc $row->[1]} = 1;
    $self->db_tree->{'ALL_WEB_SPECIES'}{$row->[2]}    = 1;
    $self->db_tree->{'ENSEMBL_VEGA'}{$row->[0]}       = $row->[3] eq 'Y' ? 1 : 0;
  }

  $dbh->disconnect();
}

sub _build_compara_default_aligns {
  my ($self,$dbh,$dest) = @_;
  my $sth = $dbh->prepare(qq(
    select mlss.method_link_species_set_id
      from method_link_species_set as mlss
      join method_link as ml on mlss.method_link_id = ml.method_link_id
      join species_set_header as ssh on mlss.species_set_id = ssh.species_set_id
     where ml.type = ?
       and ssh.name = ?
  ));
  my @defaults;
  my $cda_conf = $self->full_tree->{'MULTI'}{'COMPARA_DEFAULT_ALIGNMENTS'};
  foreach my $species (keys %$cda_conf) {
    my $method = $cda_conf->{$species};
    $sth->bind_param(1,$method);
    $sth->bind_param(2,$species);
    $sth->execute;
    my ($mlss_id)= $sth->fetchrow_array;
    push @defaults,[$mlss_id,$species,$method];
    $sth->execute;
    $sth->finish;
  }
  $dest->{'COMPARA_DEFAULT_ALIGNMENT_IDS'} = \@defaults;
}

sub _build_compara_mlss {
  my ($self,$dbh,$dest) = @_;

  my $sth = $dbh->prepare(qq(
    select mlss.method_link_species_set_id,
           ss.species_set_id,
           ml.method_link_id
      from method_link_species_set as mlss
      join species_set as ss
        on mlss.species_set_id = ss.species_set_id
      join method_link as ml
        on mlss.method_link_id = ml.method_link_id
  ));
  $sth->execute;
  my %mlss;
  while(my ($mlss_id,$ss_id,$ml_id) = $sth->fetchrow_array) {
    $mlss{$mlss_id} = { SPECIES_SET => $ss_id, METHOD_LINK => $ml_id };
  }
  $dest->{'MLSS_IDS'} = \%mlss;
}

sub _summarise_compara_db {
  my ($self, $code, $db_name) = @_;
  
  my $dbh = $self->db_connect($db_name);
  return unless $dbh;
  
  push @{$self->db_tree->{'compara_like_databases'}}, $db_name;

  $self->_summarise_generic($db_name, $dbh);
  
  # See if there are any intraspecies alignments (ie a self compara)
  my $intra_species_aref = $dbh->selectall_arrayref('
    select mls.species_set_id, mls.method_link_species_set_id, count(*) as count
      from method_link_species_set as mls, 
        method_link as ml, species_set as ss, genome_db as gd 
      where mls.species_set_id = ss.species_set_id
        and ss.genome_db_id = gd.genome_db_id 
        and mls.method_link_id = ml.method_link_id
        and ml.type LIKE "LASTZ%"
      group by mls.method_link_species_set_id, mls.method_link_id
      having count = 1
  ');
  
  my (%intra_species, %intra_species_constraints);
  $intra_species{$_->[0]}{$_->[1]} = 1 for @$intra_species_aref;
  
  # look at all the multiple alignments
  ## We've done the DB hash...So lets get on with the multiple alignment hash;
  my $res_aref = $dbh->selectall_arrayref('
    select ml.class, ml.type, gd.name, mlss.name, mlss.method_link_species_set_id, ss.species_set_id
      from method_link ml, 
        method_link_species_set mlss, 
        genome_db gd, species_set ss 
      where mlss.method_link_id = ml.method_link_id and
        mlss.species_set_id = ss.species_set_id and 
        ss.genome_db_id = gd.genome_db_id and
        (ml.class like "GenomicAlign%" or ml.class like "%.constrained_element" or ml.class = "ConservationScore.conservation_score")
  ');
  
  my $constrained_elements = {};
  my %valid_species = map { $_ => 1 } keys %{$self->full_tree};
  # Check if contains a species not in vega - use to determine whether or not to run vega specific queries
  my $vega = 1;
  
  foreach my $row (@$res_aref) { 
    my ($class, $type, $species, $name, $id, $species_set_id) = ($row->[0], uc $row->[1], ucfirst $row->[2], $row->[3], $row->[4], $row->[5]);
    my $key = 'ALIGNMENTS';
    
    if ($class =~ /ConservationScore/ || $type =~ /CONSERVATION_SCORE/) {
      $key  = 'CONSERVATION_SCORES';
      $name = 'Conservation scores';
    } elsif ($class =~ /constrained_element/ || $type =~ /CONSTRAINED_ELEMENT/) {
      $key = 'CONSTRAINED_ELEMENTS';
      $constrained_elements->{$species_set_id} = $id;
    } elsif ($type !~ /EPO_LOW_COVERAGE/ && ($class =~ /tree_alignment/ || $type  =~ /EPO/)) {
      $self->db_tree->{$db_name}{$key}{$id}{'species'}{'ancestral_sequences'} = 1 unless exists $self->db_tree->{$db_name}{$key}{$id};
    }
    
    $vega = 0 if $species eq 'Ailuropoda_melanoleuca';
    
    if ($intra_species{$species_set_id}) {
      $intra_species_constraints{$species}{$_} = 1 for keys %{$intra_species{$species_set_id}};
    }
    
    $species =~ tr/ /_/;
   
    $self->db_tree->{$db_name}{$key}{$id}{'id'}                = $id;
    $self->db_tree->{$db_name}{$key}{$id}{'name'}              = $name;
    $self->db_tree->{$db_name}{$key}{$id}{'type'}              = $type;
    $self->db_tree->{$db_name}{$key}{$id}{'class'}             = $class;
    $self->db_tree->{$db_name}{$key}{$id}{'species_set_id'}    = $species_set_id;
    $self->db_tree->{$db_name}{$key}{$id}{'species'}{$species} = 1;
  }
  
  foreach my $species_set_id (keys %$constrained_elements) {
    my $constr_elem_id = $constrained_elements->{$species_set_id};
    
    foreach my $id (keys %{$self->db_tree->{$db_name}{'ALIGNMENTS'}}) {
      $self->db_tree->{$db_name}{'ALIGNMENTS'}{$id}{'constrained_element'} = $constr_elem_id if $self->db_tree->{$db_name}{'ALIGNMENTS'}{$id}{'species_set_id'} == $species_set_id;
    }
  }

  $res_aref = $dbh->selectall_arrayref('SELECT method_link_species_set_id, value FROM method_link_species_set_tag JOIN method_link_species_set USING (method_link_species_set_id) JOIN method_link USING (method_link_id) WHERE type LIKE "%CONSERVATION\_SCORE" AND tag = "msa_mlss_id"');
  
  foreach my $row (@$res_aref) {
    my ($conservation_score_id, $alignment_id) = ($row->[0], $row->[1]);
    
    next unless $conservation_score_id;
    
    $self->db_tree->{$db_name}{'ALIGNMENTS'}{$alignment_id}{'conservation_score'} = $conservation_score_id;
  }
  
  # if there are intraspecies alignments then get full details of genomic alignments, ie start and stop, constrained by a set defined above (or no constraint for all alignments)
  $self->_summarise_compara_alignments($dbh, $db_name, $vega ? undef : \%intra_species_constraints) if scalar keys %intra_species_constraints;
  
  my %sections = (
    ENSEMBL_ORTHOLOGUES => 'GENE',
    HOMOLOGOUS_GENE     => 'GENE',
    HOMOLOGOUS          => 'GENE',
  );
  
  # We've done the DB hash... So lets get on with the DNA, SYNTENY and GENE hashes;
  $res_aref = $dbh->selectall_arrayref('
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
  ');
  
  ## That's the end of the compara region munging!

  my $res_aref_2 = $dbh->selectall_arrayref(qq{
    select ml.type, gd.name, gd.name, count(*) as count
      from method_link_species_set as mls, method_link as ml, species_set as ss, genome_db as gd 
      where mls.species_set_id = ss.species_set_id and
        ss.genome_db_id = gd.genome_db_id and
        mls.method_link_id = ml.method_link_id and
        ml.type not like '%PARALOGUES'
      group by mls.method_link_species_set_id, mls.method_link_id
      having count = 1
  });
  
  push @$res_aref, $_ for @$res_aref_2;
  
  foreach my $row (@$res_aref) {
    my ($species1, $species2) = (ucfirst $row->[1], ucfirst $row->[2]);
    
    $species1 =~ tr/ /_/;
    $species2 =~ tr/ /_/;
    
    my $key = $sections{uc $row->[0]} || uc $row->[0];
    
    $self->db_tree->{$db_name}{$key}{$species1}{$species2} = $valid_species{$species2};
  }             
  
  ###################################################################
  ## Section for colouring and colapsing/hidding genes per species in the GeneTree View
  
  # The config for taxon-groups is in DEFAULTS.ini
  # Here, we only need to add the "special" set of low-coverage species
  $res_aref = $dbh->selectall_arrayref(q{SELECT genome_db_id FROM genome_db WHERE is_high_coverage = 0});
  $self->db_tree->{$db_name}{'SPECIES_SET'}{'LOWCOVERAGE'} = [map {$_->[0]} @$res_aref];

  ## End section about colouring and colapsing/hidding gene in the GeneTree View
  ###################################################################

  ###################################################################
  ## Cache MLSS for quick lookup in ImageConfig

  $self->_build_compara_default_aligns($dbh,$self->db_tree->{$db_name});
  $self->_build_compara_mlss($dbh,$self->db_tree->{$db_name});

  ##
  ###################################################################

  ###################################################################
  ## Section for storing the genome_db_ids <=> species_name
  $res_aref = $dbh->selectall_arrayref('SELECT genome_db_id, name, assembly FROM genome_db');
  
  foreach my $row (@$res_aref) {
    my ($genome_db_id, $species_name) = @$row;
    
    $species_name =~ tr/ /_/;
    
    $self->db_tree->{$db_name}{'GENOME_DB'}{$species_name} = $genome_db_id;
    $self->db_tree->{$db_name}{'GENOME_DB'}{$genome_db_id} = $species_name;
  }
  ###################################################################
  
  ###################################################################
  ## Section for storing the taxa properties
  
  # Default name is the name stored in species_tree_node: the glyphset will use it by default

  # But a better name is the ensembl alias
  $res_aref = $dbh->selectall_arrayref(qq(SELECT taxon_id, name FROM ncbi_taxa_name WHERE name_class='ensembl alias name'));
  foreach my $row (@$res_aref) {
    my ($taxon_id, $taxon_name) = @$row;
    $self->db_tree->{$db_name}{'TAXON_NAME'}{$taxon_id} = $taxon_name;
  }

  # And we need the age of each ancestor
  $res_aref = $dbh->selectall_arrayref(qq(SELECT taxon_id, name FROM ncbi_taxa_name WHERE name_class='ensembl timetree mya'));
  foreach my $row (@$res_aref) {
    my ($taxon_id, $taxon_mya) = @$row;
    $self->db_tree->{$db_name}{'TAXON_MYA'}{$taxon_id} = $taxon_mya;
  }


  ###################################################################
  
  $dbh->disconnect;
}

sub _summarise_compara_alignments {
  my ($self, $dbh, $db_name, $constraint) = @_;
  my (%config, $lookup_species, @method_link_species_set_ids);

  my $vega = !(defined $constraint);

  if ($constraint) {
    $lookup_species              = join ',', map $dbh->quote($_), sort keys %$constraint;
    @method_link_species_set_ids = map keys %$_, values %$constraint;
  }
  
  # get details of seq_regions in the database
  my $q = '
    select df.dnafrag_id, df.name, df.coord_system_name, gdb.name
      from dnafrag df, genome_db gdb
      where df.genome_db_id = gdb.genome_db_id
  ';
  
  $q .= " and gdb.name in ($lookup_species)", if $lookup_species;
  
  my $sth = $dbh->prepare($q);
  my $rv  = $sth->execute || die $sth->errstr;
  
  my %genomic_regions;
  
  while (my ($dnafrag_id, $sr, $coord_system, $species) = $sth->fetchrow_array) {
    $species =~ s/ /_/;
    
    $genomic_regions{$dnafrag_id} = {
      species      => $species,
      seq_region   => $sr,
      coord_system => $coord_system,
    };
  }

  # get details of methods in the database -
  $q = '
    select mlss.method_link_species_set_id, ml.type, ml.class, mlss.name
      from method_link_species_set mlss, method_link ml
      where mlss.method_link_id = ml.method_link_id
  ';
  
  $sth = $dbh->prepare($q);
  $rv  = $sth->execute || die $sth->errstr;
  my (%methods, %names, %classes);
  
  while (my ($mlss, $type, $class, $name) = $sth->fetchrow_array) {
    $methods{$mlss} = $type;
    $names{$mlss}   = $name;
    $classes{$mlss} = $class;
  }
  
  # get details of alignments
  my @where;
  push @where,"is_reference = 0" unless $vega;
  if(@method_link_species_set_ids) {
    my $mlss = join(',',@method_link_species_set_ids);
    push @where,"ga_ref.method_link_species_set_id in ($mlss)";
  }
  my $where = '';
  $where = "WHERE ".join(' AND ',@where) if(@where);
  $q = sprintf('
    select genomic_align_block_id, ga.method_link_species_set_id, ga.dnafrag_start, ga.dnafrag_end, ga.dnafrag_id
      from genomic_align ga_ref join dnafrag using (dnafrag_id) join genomic_align ga using (genomic_align_block_id)
      %s
      order by genomic_align_block_id, ga.dnafrag_id',
      $where
  );
  
  $sth = $dbh->prepare($q);
  $rv  = $sth->execute || die $sth->errstr;
      
  # parse the data
  my (@seen_ids, $prev_id, $prev_df_id, $prev_comparison, $prev_method, $prev_start, $prev_end, $prev_sr, $prev_species, $prev_coord_sys);
  
  while (my ($gabid, $mlss_id, $start, $end, $df_id) = $sth->fetchrow_array) {
    my $id = $gabid . $mlss_id;
    
    if ($id eq $prev_id) {
      my $this_method    = $methods{$mlss_id};
      my $this_sr        = $genomic_regions{$df_id}->{'seq_region'};
      my $this_species   = ucfirst $genomic_regions{$df_id}->{'species'};
      my $this_coord_sys = $genomic_regions{$df_id}->{'coord_system'};
      my $comparison     = "$this_sr:$prev_sr";
      my $coords         = "$this_coord_sys:$prev_coord_sys";
      
      $config{$this_method}{$this_species}{$prev_species}{$comparison}{'coord_systems'}  = "$coords";  # add a record of the coord systems used (might be needed for zebrafish ?)
      $config{$this_method}{$this_species}{$prev_species}{$comparison}{'source_name'}    = "$this_sr"; # add names of compared regions
      $config{$this_method}{$this_species}{$prev_species}{$comparison}{'source_species'} = "$this_species";
      $config{$this_method}{$this_species}{$prev_species}{$comparison}{'target_name'}    = "$prev_sr";
      $config{$this_method}{$this_species}{$prev_species}{$comparison}{'target_species'} = "$prev_species";
      $config{$this_method}{$this_species}{$prev_species}{$comparison}{'mlss_id'}        = "$mlss_id";
      
      $self->_get_regions(\%config, $this_method, $comparison, $this_species, $prev_species, $start, $prev_start, 'start'); # look for smallest start in this comparison
      $self->_get_regions(\%config, $this_method, $comparison, $this_species, $prev_species, $end,   $prev_end,   'end');   # look for largest ends in this comparison
    } else {
      $prev_id        = $id;
      $prev_df_id     = $df_id;
      $prev_start     = $start;
      $prev_end       = $end;
      $prev_sr        = $genomic_regions{$df_id}->{'seq_region'};
      $prev_species   = ucfirst $genomic_regions{$df_id}->{'species'};
      $prev_coord_sys = $genomic_regions{$df_id}->{'coord_system'};
    }        
  }
  
  # add reciprocal entries for each comparison
  foreach my $method (keys %config) {
    foreach my $p_species (keys %{$config{$method}}) {
      foreach my $s_species (keys %{$config{$method}{$p_species}}) {                                                
        foreach my $comp (keys %{$config{$method}{$p_species}{$s_species}}) {
          my $revcomp = join ':', reverse(split ':', $comp);
          
          if (!exists $config{$method}{$s_species}{$p_species}{$revcomp}) {
            my $coords = $config{$method}{$p_species}{$s_species}{$comp}{'coord_systems'};
            my ($a,$b) = split ':', $coords;
            
            $coords = "$b:$a";
            
            my $record = {
              source_name    => $config{$method}{$p_species}{$s_species}{$comp}{'target_name'},
              source_species => $config{$method}{$p_species}{$s_species}{$comp}{'target_species'},
              source_start   => $config{$method}{$p_species}{$s_species}{$comp}{'target_start'},
              source_end     => $config{$method}{$p_species}{$s_species}{$comp}{'target_end'},
              target_name    => $config{$method}{$p_species}{$s_species}{$comp}{'source_name'},
              target_species => $config{$method}{$p_species}{$s_species}{$comp}{'source_species'},
              target_start   => $config{$method}{$p_species}{$s_species}{$comp}{'source_start'},
              target_end     => $config{$method}{$p_species}{$s_species}{$comp}{'source_end'},
              mlss_id        => $config{$method}{$p_species}{$s_species}{$comp}{'mlss_id'},
              coord_systems  => $coords,
            };
            
            $config{$method}{$s_species}{$p_species}{$revcomp} = $record;
          }
        }
      }
    }
  }

  # get a summary of the regions present
  my $region_summary;
  foreach my $method (keys %config) {
    foreach my $p_species (keys %{$config{$method}}) {
      foreach my $s_species (keys %{$config{$method}{$p_species}}) {                                                
        foreach my $comp (keys %{$config{$method}{$p_species}{$s_species}}) {
          my $target_name  = $config{$method}{$p_species}{$s_species}{$comp}{'target_name'};
          my $source_name  = $config{$method}{$p_species}{$s_species}{$comp}{'source_name'};
          my $source_start = $config{$method}{$p_species}{$s_species}{$comp}{'source_start'};
          my $source_end   = $config{$method}{$p_species}{$s_species}{$comp}{'source_end'};
          my $mlss_id      = $config{$method}{$p_species}{$s_species}{$comp}{'mlss_id'};
          my $name         = $names{$mlss_id};
          my ($homologue)  = grep $_ != $mlss_id, @method_link_species_set_ids;
          
          push @{$region_summary->{ucfirst $p_species}{$source_name}}, {
            species     => { ucfirst "$s_species--$target_name" => 1, ucfirst "$p_species--$source_name" => 1 },
            target_name => $target_name,
            start       => $source_start,
            end         => $source_end,
            id          => $mlss_id,
            name        => $name,
            type        => $method,
            class       => $classes{$mlss_id},
            homologue   => $methods{$homologue}
          };
        }
      }
    }
  }
  
  my $key = $constraint ? 'INTRA_SPECIES_ALIGNMENTS' : 'ALIGNMENTS';
  
  foreach my $method (keys %config) {
    $self->db_tree->{$db_name}{$key}{$method} = $config{$method};
  }
  
  $self->db_tree->{$db_name}{$key}{'REGION_SUMMARY'} = $region_summary;
}

sub _get_regions {
  #compare regions to get the smallest start and largest end
  my $self = shift;
  my ($config,$method,$comparison,$species1,$species2,$location1,$location2,$condition) = @_;
  if ($config->{$method}{$species1}{$species2}{$comparison}{'source_'.$condition}) {
    if ($self->_comp_se( $condition,$location1,$config->{$method}{$species1}{$species2}{$comparison}{'source_'.$condition} )) {
      $config->{$method}{$species1}{$species2}{$comparison}{'source_'.$condition} = $location1;
    }
  }
  else {
    $config->{$method}{$species1}{$species2}{$comparison}{'source_'.$condition} = $location1;        
  }

  if ($config->{$method}{$species1}{$species2}{$comparison}{'target_'.$condition}) {
    if ($self->_comp_se( $condition,$location2,$config->{$method}{$species1}{$species2}{$comparison}{'target_'.$condition} )) {
      $config->{$method}{$species1}{$species2}{$comparison}{'target_'.$condition} = $location2;
    }
  }
  else {
    $config->{$method}{$species1}{$species2}{$comparison}{'target_'.$condition} = $location2;        
  }
}

sub _comp_se {
# compare start (less than) or end (greater than) regions depending on condition
  my $self = shift;
  my ($condition, $location1, $location2) = @_;
  if ($condition eq 'start') {
    return $location1 < $location2 ? 1 : 0;
  }
  if ($condition eq 'end') {
    return $location1 > $location2 ? 1 : 0;
  }
}


sub _summarise_ancestral_db {
  my($self,$code,$db_name) = @_;
  my $dbh     = $self->db_connect( $db_name );
  return unless $dbh;
  $self->_summarise_generic( $db_name, $dbh );
  $dbh->disconnect();
}

sub _summarise_go_db {
  my $self = shift;
  my $db_name = 'DATABASE_GO';
  my $dbh     = $self->db_connect( $db_name );
  return unless $dbh;
  #$self->_summarise_generic( $db_name, $dbh );
  # get the list of the available ontologies
  my $t_aref = $dbh->selectall_arrayref(
     'select ontology.ontology_id, ontology.name, accession, term.name
      from ontology
        join term using (ontology_id)
      where is_root = 1
      order by ontology.ontology_id');
  foreach my $row (@$t_aref) {
      my ($oid, $ontology, $root_term, $description) = @$row;
      $self->db_tree->{'ONTOLOGIES'}->{$oid} = {
    db => $ontology,
    root => $root_term,
    description => $description
    };
  }

  $dbh->disconnect();
}

sub _munge_meta {
  my $self = shift;
  
  ##################################################
  # All species info is keyed on the standard URL: #
  # SPECIES_URL             = Homo_sapiens         #
  # (for backwards compatibility, we also set this #
  # value as SPECIES_BIO_NAME, but deprecated)     #
  #                                                #
  # Name used in headers and dropdowns             #
  # SPECIES_COMMON_NAME     = Human                #
  #                                                #
  # Database root name (also used with compara?)   #                        
  # SPECIES_PRODUCTION_NAME = homo_sapiens         #
  #                                                #
  # Full scientific name shown on species homepage #
  # SPECIES_SCIENTIFIC_NAME = Homo sapiens         #
  ##################################################
  
  my %keys = qw(
    species.taxonomy_id           TAXONOMY_ID
    species.url                   SPECIES_URL
    species.stable_id_prefix      SPECIES_PREFIX
    species.display_name          SPECIES_COMMON_NAME
    species.production_name       SPECIES_PRODUCTION_NAME
    species.scientific_name       SPECIES_SCIENTIFIC_NAME
    assembly.accession            ASSEMBLY_ACCESSION
    assembly.web_accession_source ASSEMBLY_ACCESSION_SOURCE
    assembly.web_accession_type   ASSEMBLY_ACCESSION_TYPE
    assembly.name                 ASSEMBLY_NAME
    liftover.mapping              ASSEMBLY_MAPPINGS
    genebuild.method              GENEBUILD_METHOD
    provider.name                 PROVIDER_NAME
    provider.url                  PROVIDER_URL
    provider.logo                 PROVIDER_LOGO
    species.strain                SPECIES_STRAIN
    species.sql_name              SYSTEM_NAME
    genome.assembly_type          GENOME_ASSEMBLY_TYPE
    gencode.version               GENCODE_VERSION
  );
  
  my @months    = qw(blank Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
  my $meta_info = $self->_meta_info('DATABASE_CORE') || {};
  my @sp_count  = grep { $_ > 0 } keys %$meta_info;

  ## How many species in database?
  $self->tree->{'SPP_IN_DB'} = scalar @sp_count;
    
  if (scalar @sp_count > 1) {
    if ($meta_info->{0}{'species.group'}) {
      $self->tree->{'DISPLAY_NAME'} = $meta_info->{0}{'species.group'};
    } else {
      (my $group_name = $self->{'_species'}) =~ s/_collection//;
      $self->tree->{'DISPLAY_NAME'} = $group_name;
    }
  } else {
    $self->tree->{'DISPLAY_NAME'} = $meta_info->{1}{'species.display_name'}[0];
  }

  while (my ($species_id, $meta_hash) = each (%$meta_info)) {
    next unless $species_id && $meta_hash && ref($meta_hash) eq 'HASH';
    
    my $species  = $meta_hash->{'species.url'}[0] || ucfirst $meta_hash->{'species.production_name'}[0];
    my $bio_name = $meta_hash->{'species.scientific_name'}[0];
    
    ## Put other meta info into variables
    while (my ($meta_key, $key) = each (%keys)) {
      next unless $meta_hash->{$meta_key};
      
      my $value = scalar @{$meta_hash->{$meta_key}} > 1 ? $meta_hash->{$meta_key} : $meta_hash->{$meta_key}[0]; 

      ## Set version of assembly name that we can use where space is limited 
      if ($meta_key eq 'assembly.name') {
        $self->tree->{$species}{'ASSEMBLY_SHORT_NAME'} = (length($value) > 16)
                  ? $self->db_tree->{'ASSEMBLY_VERSION'} : $value;
      }

      $self->tree->{$species}{$key} = $value;
    }


    ## Do species group
    my $taxonomy = $meta_hash->{'species.classification'};
    
    if ($taxonomy && scalar(@$taxonomy)) {
      my %valid_taxa = map {$_ => 1} @{ $self->tree->{'TAXON_ORDER'} };
      my @matched_groups = grep {$valid_taxa{$_}} @$taxonomy;
      $self->tree->{$species}{'SPECIES_GROUP'} = $matched_groups[0] if @matched_groups;
      $self->tree->{$species}{'SPECIES_GROUP_HIERARCHY'} = \@matched_groups;
    }

    ## create lookup hash for species aliases
    foreach my $alias (@{$meta_hash->{'species.alias'}}) {
      $self->full_tree->{'MULTI'}{'SPECIES_ALIASES'}{$alias} = $species;
    }

    ## Backwards compatibility
    $self->tree->{$species}{'SPECIES_BIO_NAME'}  = $bio_name;
    ## Used mainly in <head> links
    ($self->tree->{$species}{'SPECIES_BIO_SHORT'} = $bio_name) =~ s/^([A-Z])[a-z]+_([a-z]+)$/$1.$2/;
    
    if ($self->tree->{'ENSEMBL_SPECIES'}) {
      push @{$self->tree->{'DB_SPECIES'}}, $species;
    } else {
      $self->tree->{'DB_SPECIES'} = [ $species ];
    }

    
    $self->tree->{$species}{'SPECIES_META_ID'} = $species_id;

    ## Munge genebuild info
    my @A = split '-', $meta_hash->{'genebuild.start_date'}[0];
    
    $self->tree->{$species}{'GENEBUILD_START'} = $A[1] ? "$months[$A[1]] $A[0]" : undef;
    $self->tree->{$species}{'GENEBUILD_BY'}    = $A[2];

    @A = split '-', $meta_hash->{'genebuild.initial_release_date'}[0];
    
    $self->tree->{$species}{'GENEBUILD_RELEASE'} = $A[1] ? "$months[$A[1]] $A[0]" : undef;
    
    @A = split '-', $meta_hash->{'genebuild.last_geneset_update'}[0];

    $self->tree->{$species}{'GENEBUILD_LATEST'} = $A[1] ? "$months[$A[1]] $A[0]" : undef;
    
    @A = split '-', $meta_hash->{'assembly.date'}[0];
    
    $self->tree->{$species}{'ASSEMBLY_DATE'} = $A[1] ? "$months[$A[1]] $A[0]" : undef;
    

    $self->tree->{$species}{'HAVANA_DATAFREEZE_DATE'} = $meta_hash->{'genebuild.havana_datafreeze_date'}[0];

    # check if there are sample search entries defined in meta table ( the case with Ensembl Genomes)
    # they can be overwritten at a later stage  via INI files
    my @ks = grep { /^sample\./ } keys %{$meta_hash || {}}; 
    my $shash;

    foreach my $k (@ks) {
      (my $k1 = $k) =~ s/^sample\.//;
      $shash->{uc $k1} = $meta_hash->{$k}->[0];
    }
    ## add in any missing values where text omitted because same as param
    while (my ($key, $value) = each (%$shash)) {
      next unless $key =~ /PARAM/;
      (my $type = $key) =~ s/_PARAM//;
      unless ($shash->{$type.'_TEXT'}) {
        $shash->{$type.'_TEXT'} = $value;
      } 
    }

    $self->tree->{$species}{'SAMPLE_DATA'} = $shash if scalar keys %$shash;

    # check if the karyotype/list of toplevel regions ( normally chroosomes) is defined in meta table
    @{$self->tree($species)->{'TOPLEVEL_REGIONS'}} = @{$meta_hash->{'regions.toplevel'}} if $meta_hash->{'regions.toplevel'};
  }
}

sub _munge_variation {
  my $self = shift;
  my $dbh     = $self->db_connect('DATABASE_VARIATION');
  return unless $dbh;
  return unless $self->db_details('DATABASE_VARIATION');
  my $total = 0;
  if ( $self->tree->{'databases'}{'DATABASE_VARIATION'}{'DISPLAY_STRAINS'} ) {
    $total +=  @{ $self->tree->{'databases'}{'DATABASE_VARIATION'}{'DISPLAY_STRAINS'} };
  }
  if ( $self->tree->{'databases'}{'DATABASE_VARIATION'}{'DEFAULT_STRAINS'} ) {
    $total +=  @{ $self->tree->{'databases'}{'DATABASE_VARIATION'}{'DEFAULT_STRAINS'} }; 
  }
  $self->tree->{'databases'}{'DATABASE_VARIATION'}{'#STRAINS'} = $total;
    $self->tree->{'databases'}{'DATABASE_VARIATION'}{'DEFAULT_LD_POP'}   = $self->_meta_info('DATABASE_VARIATION','pairwise_ld.default_population')->[0] if $self->_meta_info('DATABASE_VARIATION','pairwise_ld.default_population');
}

sub _munge_website {
  my $self = shift;

  ## Release info for ID history etc
  $self->tree->{'ASSEMBLIES'}       = $self->db_multi_tree->{'ASSEMBLIES'}{$self->{_species}};
}

sub _munge_website_multi {
  my $self = shift;

  $self->tree->{'ENSEMBL_HELP'} = $self->db_tree->{'ENSEMBL_HELP'};
  $self->tree->{'ENSEMBL_GLOSSARY'} = $self->db_tree->{'ENSEMBL_GLOSSARY'};
}

sub _munge_file_formats {
  my $self = shift;

  my %unsupported = map {uc($_) => 1} @{$self->tree->{'UNSUPPORTED_FILE_FORMATS'}||[]};
  my (@upload, @remote);

  ## Get info on all formats
  my %formats = (
    'bed'       => {'ext' => 'bed', 'label' => 'BED',       'display' => 'feature'},
    'bedgraph'  => {'ext' => 'bed', 'label' => 'bedGraph',  'display' => 'graph'},
    'gff'       => {'ext' => 'gff', 'label' => 'GFF',       'display' => 'feature'},
    'gtf'       => {'ext' => 'gtf', 'label' => 'GTF',       'display' => 'feature'},
    'psl'       => {'ext' => 'psl', 'label' => 'PSL',       'display' => 'feature'},
    'vcf'       => {'ext' => 'vcf', 'label' => 'VCF',       'display' => 'graph'},
    'vep_input' => {'ext' => 'txt', 'label' => 'VEP',       'display' => 'feature'},
    'wig'       => {'ext' => 'wig', 'label' => 'WIG',       'display' => 'graph'},
    ## Remote only - cannot be uploaded
    'bam'       => {'ext' => 'bam', 'label' => 'BAM',       'display' => 'graph', 'remote' => 1},
    'bigwig'    => {'ext' => 'bw',  'label' => 'BigWig',    'display' => 'graph', 'remote' => 1},
    'bigbed'    => {'ext' => 'bb',  'label' => 'BigBed',    'display' => 'graph', 'remote' => 1},
    'cram'      => {'ext' => 'cram','label' => 'CRAM',      'display' => 'graph', 'remote' => 1},
    'trackhub'  => {'ext' => 'txt', 'label' => 'Track Hub', 'display' => 'graph', 'remote' => 1},
    ## Export only
    'fasta'     => {'ext' => 'fa',   'label' => 'FASTA'},
    'clustalw'  => {'ext' => 'aln',  'label' => 'CLUSTALW'},
    'msf'       => {'ext' => 'msf',  'label' => 'MSF'},
    'mega'      => {'ext' => 'meg',  'label' => 'Mega'},
    'newick'    => {'ext' => 'nh',   'label' => 'Newick'},
    'nexus'     => {'ext' => 'nex',  'label' => 'Nexus'},
    'nhx'       => {'ext' => 'nhx',  'label' => 'NHX'},
    'orthoxml'  => {'ext' => 'xml',  'label' => 'OrthoXML'},
    'phylip'    => {'ext' => 'phy',  'label' => 'Phylip'},
    'phyloxml'  => {'ext' => 'xml',  'label' => 'PhyloXML'},
    'pfam'      => {'ext' => 'pfam', 'label' => 'Pfam'},
    'psi'       => {'ext' => 'psi',  'label' => 'PSI'},
    'rtf'       => {'ext' => 'rtf',  'label' => 'RTF'},
    'stockholm' => {'ext' => 'stk',  'label' => 'Stockholm'},
    'emboss'    => {'ext' => 'txt',  'label' => 'EMBOSS'},
    ## WashU formats
    'pairwise'  => {'ext' => 'txt', 'label' => 'Pairwise interactions', 'display' => 'feature'},
    'pairwise_tabix' => {'ext' => 'txt', 'label' => 'Pairwise interactions (indexed)', 'display' => 'feature', 'indexed' => 1},
  );

  ## Munge into something useful to this website
  while (my ($format, $details) = each (%formats)) {
    my $uc_name = uc($format);
    if ($unsupported{$uc_name}) {
      delete $formats{$format};
      next;
    }
    if ($details->{'remote'}) {
      push @remote, $format;
    }
    elsif ($details->{'display'}) {
      push @upload, $format;
    }
  }

  $self->tree->{'UPLOAD_FILE_FORMATS'} = \@upload;
  $self->tree->{'REMOTE_FILE_FORMATS'} = \@remote;
  $self->tree->{'DATA_FORMAT_INFO'} = \%formats;
}

1;
