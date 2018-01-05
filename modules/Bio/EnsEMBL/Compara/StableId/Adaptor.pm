=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::StableId::Adaptor

=head1 DESCRIPTION

All database I/O should be done via this class,
which has a general functionality of an adaptor, but strictly speaking isn't.

=cut

package Bio::EnsEMBL::Compara::StableId::Adaptor;

use strict;
use warnings;
use DBI;
use Bio::EnsEMBL::Utils::Argument;  # import 'rearrange()'
use Bio::EnsEMBL::Compara::StableId::NamedClusterSet;
use Bio::EnsEMBL::Compara::StableId::Map;
use Bio::EnsEMBL::Utils::Exception qw(throw);

sub new {
    my $class = shift @_;

    my $self = bless { }, $class;

    my ($release_in_progress, $dg_suffix_in_progress, $dbname_in_progress, $hist_contrib_unit) =
         rearrange([qw(release_in_progress dg_suffix_in_progress dbname_in_progress hist_contrib_unit) ], @_);

    $self->release_in_progress($release_in_progress) if(defined($release_in_progress));
    $self->dg_suffix_in_progress($dg_suffix_in_progress) if(defined($dg_suffix_in_progress));
    $self->dbname_in_progress($dbname_in_progress) if(defined($dbname_in_progress));
    $self->hist_contrib_unit($hist_contrib_unit || 100);

    return $self;
}

sub treefam_dbh {
    my ($self, $release) = @_;

    return DBI->connect("DBI:mysql:mysql_use_result=1;host=mysql-treefam-public.ebi.ac.uk;port=4418;database=treefam_production_${release}", 'treefam_ro', '');
}

sub dbh_from_dgsuffix_dbname {
    my ($self, $dg_suffix, $dbname) = @_;

    my $dbh = DBI->connect("DBI:mysql:mysql_read_default_group=client${dg_suffix};mysql_use_result=1;database=${dbname}") or die "Connection Error: $DBI::errstr\n";

    return $dbh;
}

sub guess_dbh {     # only works if you have .my.cnf properly pre-filled with connection parameters
    my ($self, $release, $type) = @_;

    if($type eq 'tf') {

        warn "${type}${release} - going to load the data from 'treefam_${release}'\n";

        return $self->treefam_dbh($release);

    } elsif (($type eq 'f') or ($type eq 't')) {
        
        my($dg_suffix, $dbname);

        if($self->release_in_progress() and ($release==$self->release_in_progress())) {
            $dg_suffix = $self->dg_suffix_in_progress();
        } elsif ($release<=47) {
            $dg_suffix = '_archive';
        } else {
            $dg_suffix = '_narchive';
        }

        if($self->release_in_progress() and ($release==$self->release_in_progress())) {
            $dbname = $self->dbname_in_progress();
        } elsif($release>28) {
            $dbname = "ensembl_compara_${release}";
        } else {
            $dbname = "ensembl_compara_${release}_1";
        }

        warn "${type}${release} - going to load the data from '$dbname'\n";

        return $self->dbh_from_dgsuffix_dbname($dg_suffix, $dbname);
    }
}

sub fetch_ncs {
    my ($self, $release, $type, $dbh) = @_;

    $dbh ||= $self->guess_dbh($release, $type);

    my $ncs = Bio::EnsEMBL::Compara::StableId::NamedClusterSet->new(-TYPE => $type, -RELEASE => $release);

    if( ($type eq 'f') or ($type eq 't') or ($type eq 'tf') ) {
        $self->load_compara_ncs($ncs, $dbh);
    }

    return $ncs;
}


sub load_compara_ncs {
    my ($self, $ncs, $dbh) = @_;
    
    #Need the schema's version not the reported version from the 
    #NamedClusterSet as people like EG's releases are not the same as Ensembl's
    my $schema_version = $self->_get_db_version($dbh);
    warn "\t- Detected DB Version is ${schema_version}\n";

    my $step = ($ncs->type() eq 'f') ? 100000 : 30000;
    my $sql;
    if ($ncs->type() eq 'f') {
        my $member_name = $schema_version < 76 ? 'member' : 'seq_member';
        $sql = qq{
            SELECT f.family_id, }.(($schema_version<53)?"f.stable_id":"CONCAT(f.stable_id,'.',f.version)").qq{, m.stable_id
                    FROM family f, family_member fm, $member_name m
                    WHERE f.family_id=fm.family_id
                    AND   fm.${member_name}_id=m.${member_name}_id
                    AND   m.source_name <> 'ENSEMBLGENE'
            } ;
    } elsif ($ncs->type() eq 't') {
        if ($schema_version <= 52) {
            $sql = qq{
                SELECT ptn.node_id, CONCAT('Node_',ptn.node_id), m.stable_id
                    FROM protein_tree_node ptn
                    LEFT JOIN protein_tree_member n2m ON ptn.node_id=n2m.node_id
                    LEFT JOIN member m ON n2m.member_id=m.member_id
                    WHERE (ptn.parent_id = ptn.root_id  OR m.stable_id IS NOT NULL) AND left_index AND right_index
                    ORDER BY left_index 
            };
        } elsif ($schema_version <= 54) {
            $sql = qq{
                SELECT ptn.node_id, IFNULL(CONCAT(ptsi.stable_id,'.',ptsi.version), CONCAT('Node_',ptn.node_id)), m.stable_id
                    FROM protein_tree_node ptn
                    LEFT JOIN protein_tree_member n2m ON ptn.node_id=n2m.node_id
                    LEFT JOIN member m ON n2m.member_id=m.member_id
                    LEFT JOIN protein_tree_stable_id ptsi ON ptn.node_id=ptsi.node_id
                    WHERE (ptn.parent_id = ptn.root_id  OR m.stable_id IS NOT NULL) AND left_index AND right_index
                    ORDER BY left_index 
            };
        } elsif ($schema_version <= 64) {
            $sql = qq{
                SELECT ptn.node_id, IFNULL(CONCAT(ptsi.stable_id,'.',ptsi.version), CONCAT('Node_',ptn.node_id)), m.stable_id
                    FROM protein_tree_node ptn
                    LEFT JOIN protein_tree_member n2m ON ptn.node_id=n2m.node_id
                    LEFT JOIN member m ON n2m.member_id=m.member_id
                    LEFT JOIN protein_tree_stable_id ptsi ON ptn.node_id=ptsi.node_id
                    WHERE (ptn.node_id = ptn.root_id  OR m.stable_id IS NOT NULL) AND left_index AND right_index
                    ORDER BY left_index
            };
        } elsif ($schema_version == 65) {
            $sql = qq{
                SELECT ptn.node_id, IFNULL(CONCAT(ptsi.stable_id,'.',ptsi.version), CONCAT('Node_',ptn.node_id)), m.stable_id
                    FROM protein_tree_node ptn
                    LEFT JOIN protein_tree_member n2m ON ptn.node_id=n2m.node_id
                    LEFT JOIN member m ON n2m.member_id=m.member_id
                    LEFT JOIN protein_tree_stable_id ptsi ON ptn.node_id=ptsi.node_id
                    WHERE (ptn.node_id = ptn.root_id  OR m.stable_id IS NOT NULL) AND left_index AND right_index
                    ORDER BY ptn.root_id,left_index
            };
        } elsif ($schema_version == 66) {
            $sql = qq{
                SELECT gtn.node_id, IFNULL(CONCAT(gtr.stable_id,'.',gtr.version), CONCAT('Node_',gtn.node_id)), m.stable_id
                    FROM gene_tree_node gtn
                    JOIN gene_tree_root gtr USING (root_id)
                    LEFT JOIN gene_tree_member gtm USING (node_id)
                    LEFT JOIN member m USING (member_id)
                    WHERE (gtn.node_id = gtn.root_id OR m.stable_id IS NOT NULL) AND left_index AND right_index AND gtr.tree_type = 'proteintree'
                    ORDER BY root_id, left_index
            };
        } elsif ($schema_version == 67) {
            $sql = qq{
                SELECT gtn.node_id, IFNULL(CONCAT(gtr.stable_id,'.',gtr.version), CONCAT('Node_',gtn.node_id)), m.stable_id
                    FROM gene_tree_node gtn
                    JOIN gene_tree_root gtr USING (root_id)
                    LEFT JOIN gene_tree_member gtm USING (node_id)
                    LEFT JOIN member m USING (member_id)
                    WHERE (gtn.node_id = gtn.root_id OR m.stable_id IS NOT NULL) AND left_index AND right_index AND gtr.tree_type = 'tree'
                    ORDER BY root_id, left_index
            };
        } elsif ($schema_version < 70) {
            $sql = qq{
                SELECT gtn.node_id, IFNULL(CONCAT(gtr.stable_id,'.',gtr.version), CONCAT('Node_',gtn.node_id)), m.stable_id
                    FROM gene_tree_node gtn
                    JOIN gene_tree_root gtr USING (root_id)
                    LEFT JOIN gene_tree_member gtm USING (node_id)
                    LEFT JOIN member m USING (member_id)
                    WHERE (gtn.node_id = gtn.root_id OR m.stable_id IS NOT NULL) AND left_index AND right_index AND gtr.tree_type = 'tree' AND gtr.clusterset_id = 'default'
                    ORDER BY root_id, left_index
            };
        } elsif ($schema_version < 76) {
            $sql = qq{
                SELECT gtn.node_id, IFNULL(CONCAT(gtr.stable_id,'.',gtr.version), CONCAT('Node_',gtn.node_id)), m.stable_id
                    FROM gene_tree_node gtn
                    JOIN gene_tree_root gtr USING (root_id)
                    LEFT JOIN member m USING (member_id)
                    WHERE (gtn.node_id = gtn.root_id OR m.stable_id IS NOT NULL) AND left_index AND right_index AND gtr.tree_type = 'tree' AND gtr.clusterset_id = 'default'
                    ORDER BY root_id, left_index
            };
        } else {
            $sql = qq{
                SELECT gtn.node_id, IFNULL(CONCAT(gtr.stable_id,'.',gtr.version), CONCAT('Node_',gtn.node_id)), m.stable_id
                    FROM gene_tree_node gtn
                    JOIN gene_tree_root gtr USING (root_id)
                    LEFT JOIN seq_member m USING (seq_member_id)
                    WHERE (gtn.node_id = gtn.root_id OR m.stable_id IS NOT NULL) AND left_index AND right_index AND gtr.tree_type = 'tree' AND gtr.clusterset_id = 'default'
                    ORDER BY root_id, left_index
            };
        }

    } else {
        # TreeFam
        if ($schema_version <= 70) {
            $sql = qq{
                SELECT gtn.node_id, IFNULL(gtrt.value, CONCAT('Node_',gtn.node_id)), m.stable_id
                    FROM gene_tree_node gtn
                    JOIN gene_tree_root gtr USING (root_id)
                    JOIN gene_tree_root_tag gtrt ON gtr.root_id=gtrt.root_id AND gtrt.tag = "model_name"
                    LEFT JOIN gene_tree_member gtm USING (node_id)
                    LEFT JOIN member m USING (member_id)
                    WHERE (gtn.node_id = gtn.root_id OR m.member_id IS NOT NULL) AND left_index AND right_index AND gtr.tree_type = 'tree' AND gtr.clusterset_id = 'default'
                    ORDER BY gtr.root_id, left_index
            };
        }
    }

    my $sth = $dbh->prepare($sql);
    warn "\t- waiting for the data to start coming\n";
    $sth->execute();
    warn "\t- done waiting\n";
    my $counter = 0;

    my $cached_id = 0;
    my $curr_cluster_size = 'NaN';  # need a fake value that evaluates to true to start loading
    while(my($cluster_id, $cluster_name, $member)=$sth->fetchrow()) {

        $cluster_name ||= 'NoName'; # we need some name here however bogus (for formatting purposes)

        if($ncs->type() eq 'f') {
            $ncs->mname2clid($member, $cluster_id);
            $ncs->clid2clname($cluster_id, $cluster_name);
        } elsif($member) {
            if($cached_id) {
                $ncs->mname2clid($member, $cached_id);
                $curr_cluster_size++;
            } else {
                die "The query '$sql' returns orphane members without cluster_id/cluster_name, please investigate";
            }
        } else {
            if($curr_cluster_size) {
                $cached_id = $cluster_id;
                $ncs->clid2clname($cluster_id, $cluster_name);
                $curr_cluster_size=0;
            } else {
                die "The query '$sql' attempted to load an empty cluster with cluster_id='$cached_id', please investigate";
            }
        }

        unless(++$counter % $step) {
            warn "\t- $counter\n";
        }
    }
    $sth->finish();
    warn "\t- total of $counter members fetched\n";

    return $ncs;
}

sub store_map {
    my ($self, $map, $dbc) = @_;

    my $step = 3000;

    my $sql = ($map->type eq 'f')
    ? qq{
        UPDATE family
        SET stable_id = ?, version = ?
        WHERE family_id = ?
    } : ($map->type eq 't')
    ? qq{
        UPDATE gene_tree_root SET stable_id=?, version=? WHERE root_id=?
    } : die "Cannot store mapping in database. Type must be either 'f' or 't'";
    my $sth = $dbc->prepare($sql);

    my $counter = 0;
    foreach my $clid (@{ $map->get_all_clids }) {

        my ($stid, $ver) = split(/\./, $map->clid2clname($clid));

        $sth->execute($stid, $ver, $clid);
        unless(++$counter % $step) {
            warn "\t$counter mapped names stored\n";
        }
    }
    $sth->finish();
    warn "\t$counter mapped names stored, done.\n";
}

sub store_history {
    my ($self, $ncsl, $dbc, $timestamp, $master_dbc) = @_;
    
    my $mapping_session_id = $self->get_mapping_session_id($ncsl, $timestamp, $dbc, $master_dbc);
    
    my $step = 2000;
    my $counter = 0;

    my $sth = $dbc->prepare(
        "INSERT INTO stable_id_history(mapping_session_id, stable_id_from, version_from, stable_id_to, version_to, contribution) VALUES (?, ?, ?, ?, ?, ?)"
    );

    foreach my $topair (sort { $b->[1] <=> $a->[1] } map { [$_,$ncsl->to_size->{$_}] } keys %{$ncsl->to_size} ) {
        my ($to_clid, $to_size) = @$topair;
        my $subhash = $ncsl->rev_contrib->{$to_clid};

        my $to_fullname = $ncsl->to->clid2clname($to_clid)
            or die "to_fullname($to_clid) is false, please investigate";

        my ($stid_to, $ver_to) = split(/\./, $to_fullname);

        foreach my $frompair (sort { $b->[1] <=> $a->[1] } map { [$_,$subhash->{$_}] } keys %$subhash ) {
            my ($from_clid, $contrib) = @$frompair;

            my $from_fullname = $ncsl->from->clid2clname($from_clid)
                or die "from_fullname is false, please investigate.";

            my ($stid_from, $ver_from) = split(/\./, $from_fullname);

            $sth->execute($mapping_session_id, $stid_from, $ver_from, $stid_to, $ver_to, $contrib/$to_size*$self->hist_contrib_unit());

            unless(++$counter % $step) {
                warn "\t$counter history lines stored\n";
            }
        }
    }
    foreach my $to_clid (keys %{$ncsl->xto_size}) {
        my ($stid_to  , $ver_to  ) = split(/\./, $ncsl->to->clid2clname($to_clid));
        my @params = ($mapping_session_id, '', undef, $stid_to, $ver_to, 1.0*$self->hist_contrib_unit());
        eval { $sth->execute(@params); };
        throw "Cannot continue inserting into history with params '@params' when working with $to_clid and ".$ncsl->to->clid2clname($to_clid).": $@" if $@;

        unless(++$counter % $step) {
         warn "\t$counter history lines stored\n";
        }

    }
    foreach my $from_clid (keys %{$ncsl->xfrom_size}) {
            my ($stid_from, $ver_from) = split(/\./, $ncsl->from->clid2clname($from_clid));
            my @params = ($mapping_session_id, $stid_from, $ver_from, '', undef, 1.0*$self->hist_contrib_unit());
            eval { $sth->execute(@params); };
            throw "Cannot continue inserting into history with params '@params' when working with $from_clid and ".$ncsl->from->clid2clname($from_clid).": $@" if $@;


            unless(++$counter % $step) {
                warn "\t$counter history lines stored\n";
            }
    }
    $sth->finish();
    warn "\t$counter lines stored, done.\n";
}

sub get_mapping_session_id {
  my ($self, $ncsl, $timestamp, $dbc, $master_dbc) = @_;
  
  $timestamp  ||= time();
  $master_dbc ||= $dbc;       # in case no master was given (so please provide the $master_dbc to avoid doing unnecessary work afterwards)
  
  my $type = $ncsl->to->type();
  my $fulltype = { 'f' => 'family', 't' => 'tree' }->{$type} || die "Cannot store history for type '$type'";
  
  #Need to get the Generator to get the prefix and then remove the FM/GT from
  #the names. Allows us to have a default value of ENS in the mapping table
  my $generator = Bio::EnsEMBL::Compara::StableId::Generator->new(
    -TYPE => $ncsl->to->type, 
    -RELEASE => $ncsl->to->release, 
    -MAP => $ncsl->from 
  );
  my $prefix = $generator->prefix();
  my $prefix_to_remove = { f => 'FM', t => 'GT' }->{$type} || die "Do not know the extension for type '${type}'";
  $prefix =~ s/$prefix_to_remove \Z//xms;

  my $ms_sth = $master_dbc->prepare( "SELECT mapping_session_id FROM mapping_session WHERE type = ? AND rel_from = ? AND rel_to = ? AND prefix = ?" );
  $ms_sth->execute($fulltype, $ncsl->from->release(), $ncsl->to->release(), $prefix);
  my ($mapping_session_id) = $ms_sth->fetchrow_array();
  $ms_sth->finish();

  if (defined $mapping_session_id) {
    warn "reusing previously generated mapping_session_id = '$mapping_session_id' for prefix '${prefix}'\n";

  } else {
    $ms_sth = $master_dbc->prepare( "INSERT INTO mapping_session(type, rel_from, rel_to, when_mapped, prefix) VALUES (?, ?, ?, FROM_UNIXTIME(?), ?)" );
    $ms_sth->execute($fulltype, $ncsl->from->release(), $ncsl->to->release(), $timestamp, $prefix);
    $mapping_session_id = $master_dbc->db_handle->last_insert_id(undef, undef, 'mapping_session', 'mapping_session_id');
    warn "newly generated mapping_session_id = '$mapping_session_id' for prefix '${prefix}'\n";
    $ms_sth->finish();
  }

  if($dbc != $master_dbc) {   # replicate it in the release database:
      my $ms_sth2 = $dbc->prepare( "INSERT INTO mapping_session(mapping_session_id, type, rel_from, rel_to, when_mapped, prefix) VALUES (?, ?, ?, ?, FROM_UNIXTIME(?), ?)" );
      $ms_sth2->execute($mapping_session_id, $fulltype, $ncsl->from->release(), $ncsl->to->release(), $timestamp, $prefix);
      $ms_sth2->finish();
  }
  return $mapping_session_id;
}

sub store_tags {    # used to create cross-references from EnsEMBL GeneTrees to Treefam families
    my ($self, $accu, $dbh, $tag_prefix) = @_;

    $tag_prefix ||= '';

    my $step = 2000;
    
    my $sql = qq{ REPLACE INTO gene_tree_root_tag VALUES (?, ?, ?) };
    my $sth = $dbh->prepare($sql);

    my $counter = 0;
    foreach my $node_id (keys %$accu) {
        foreach my $matchtype (keys %{$accu->{$node_id}}) {

            my $value = join(';', @{$accu->{$node_id}{$matchtype}});

            my $tag = $tag_prefix .({ 'SymMatch' => 'treefam_id', 'Included' => 'part_treefam_id', 'Contains' => 'cont_treefam_id' }->{$matchtype});

            $sth->execute($node_id, $tag, $value);

            unless(++$counter % $step) {
                warn "\t$counter tags stored\n";
            }
        }
    }
    warn "\t$counter tags stored, done.\n";
}

# -------------------------------------- getters and setters ---------------------------------------------

sub release_in_progress {
    my $self = shift @_;

    if(@_) {
        $self->{'_release_in_progress'} = shift @_;
    }
    return $self->{'_release_in_progress'};
}

sub dg_suffix_in_progress {
    my $self = shift @_;

    if(@_) {
        $self->{'_dg_suffix_in_progress'} = shift @_;
    }
    return $self->{'_dg_suffix_in_progress'};
}

sub dbname_in_progress {
    my $self = shift @_;

    if(@_) {
        $self->{'_dbname_in_progress'} = shift @_;
    }
    return $self->{'_dbname_in_progress'};
}

sub hist_contrib_unit {
    my $self = shift @_;

    if(@_) {
        $self->{'_hist_contrib_unit'} = shift @_;
    }
    return $self->{'_hist_contrib_unit'};
}

sub source {
  my ($self, $source) = @_;
  $self->{_source} = $source if defined $source;
  return $self->{_source};
}

# -------------------------------------- privates ---------------------------------------------

#Have to use basic DBI because we could have been given one 
sub _get_db_version {
  my ($self, $dbh) = @_;
  my $sql = 'select meta_value from meta where meta_key =? and species_id is null LIMIT 1';
  my $sth = $dbh->prepare($sql);
  my $row;
  eval {
    $sth->execute('schema_version');
    $row = $sth->fetchrow_arrayref();
  };
  my $error = $@;
  $sth->finish();
  throw("Detected an error whilst querying for schema version: $error") if $error;
  throw('No schema_version found in meta; you really should have this') if ! $row;
  return $row->[0];
}

1;
