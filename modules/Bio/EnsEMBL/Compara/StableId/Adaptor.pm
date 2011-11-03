=pod 

=head1 NAME

  Bio::EnsEMBL::Compara::StableId::Adaptor

=head1 SYNOPSIS

=head1 DESCRIPTION

    All database I/O should be done via this class,
    which has a general functionality of an adaptor, but strictly speaking isn't.

=cut

package Bio::EnsEMBL::Compara::StableId::Adaptor;

use strict;
use DBI;
use Treefam::Tree;
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

    my $dbh = DBI->connect("DBI:mysql:mysql_use_result=1;host=db.treefam.org;port=3308;database=treefam_${release}", 'anonymous', '');
    
    return $dbh;
}

sub dbh_from_dgsuffix_dbname {
    my ($self, $dg_suffix, $dbname) = @_;

    my $dbh = DBI->connect("DBI:mysql:mysql_read_default_group=client${dg_suffix};mysql_use_result=1;database=${dbname}") or die "Connection Error: $DBI::errstr\n";

    return $dbh;
}

sub guess_dbh {     # only works if you have .my.cnf properly pre-filled with connection parameters
    my ($self, $release, $type) = @_;

    if(($type eq 'c') or ($type eq 'w')) {

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

    if( ($type eq 'f') or ($type eq 't') ) {
        $self->load_compara_ncs($ncs, $dbh);
    } elsif( ($type eq 'c') or ($type eq 'w') ) {
        $self->load_treefam_ncs($ncs, $dbh);
    }

    return $ncs;
}

sub load_treefam_ncs {
    my ($self, $ncs, $dbh) = @_;

    my $step = 30000;
    my $tree_type = ($ncs->type() eq 'c') ? 'CLEAN' : 'FULL';
    my $sql = qq{ SELECT TRIM(LEADING 'TF' FROM ac), ac, tree FROM trees WHERE type = ?};
    my $sth = $dbh->prepare($sql);
    warn "\t- waiting for the data to start coming\n";
    $sth->execute($tree_type);
    warn "\t- done waiting\n";
    my $counter = 0;

    my $dummy_dbc = {}; # let's see if it works

    while(my($tree_id, $tree_name, $tree_code) = $sth->fetchrow()) {
        next if (!$tree_code or ($tree_code eq ';') or ($tree_code eq ',_null_;') or ($tree_code eq '_null_;;[&&NHX:O=_null_;;];') );

        eval {
            my $tree = Treefam::Tree->new($dummy_dbc, $tree_name, $tree_type, $tree_code);
            foreach my $leaf ($tree->get_leaves()) {
                if(my $member = $leaf->sequence_id()) {
                    $member=~s/\.\d+$//;

                    $ncs->mname2clid($member, $tree_id);
                    $ncs->clid2clname($tree_id, $tree_name);

                    unless(++$counter % $step) {
                        warn "\t- $counter\n";
                    }
                }
            }
        };
        if($@) {
            warn "Problem with tree '$tree_name' ($@) \n TreeCode = [ $tree_code ]\n";
        }
    }
    $sth->finish();
    warn "\t- total of $counter members fetched\n";

    return $ncs;
}

sub load_compara_ncs {
    my ($self, $ncs, $dbh) = @_;
    
    #Need the schema's version not the reported version from the 
    #NamedClusterSet as people like EG's releases are not the same as Ensembl's
    my $schema_version = $self->_get_db_version($dbh);
    warn "\t- Detected DB Version is ${schema_version}\n";

    my $step = ($ncs->type() eq 'f') ? 100000 : 30000;
    my $sql = ($ncs->type() eq 'f')
    ? qq{
        SELECT f.family_id, }.(($schema_version<53)?"f.stable_id":"CONCAT(f.stable_id,'.',f.version)").qq{,
            IF(m.source_name='ENSEMBLPEP', SUBSTRING_INDEX(TRIM(LEADING 'Transcript:' FROM m.description),' ',1), m.stable_id)
        FROM family f, family_member fm, member m
        WHERE f.family_id=fm.family_id
        AND   fm.member_id=m.member_id
        AND   m.source_name <> 'ENSEMBLGENE'
    } : qq{
        SELECT ptn.node_id, }.(($schema_version<53)?"CONCAT('Node_',ptn.node_id)":"IFNULL(CONCAT(ptsi.stable_id,'.',ptsi.version), CONCAT('Node_',ptn.node_id))").qq{,
            IF(m.source_name='ENSEMBLPEP', SUBSTRING_INDEX(TRIM(LEADING 'Transcript:' FROM m.description),' ',1), m.stable_id)
        FROM protein_tree_node ptn
        LEFT JOIN protein_tree_member n2m ON ptn.node_id=n2m.node_id
        LEFT JOIN member m ON n2m.member_id=m.member_id
        }.(($schema_version<53) ? q{} :q{ LEFT JOIN protein_tree_stable_id ptsi ON ptn.node_id=ptsi.node_id}).
        ( ($schema_version < 55) ? q{ WHERE (ptn.parent_id = ptn.root_id } : q{ WHERE (ptn.node_id = ptn.root_id }).
        q{ OR m.stable_id IS NOT NULL) AND left_index AND right_index ORDER BY
        }.(($schema_version < 65) ? q{} : q{ptn.root_id,}).
        q{left_index };

    my $sth = $dbh->prepare($sql);
    warn "\t- waiting for the data to start coming\n";
    $sth->execute();
    warn "\t- done waiting\n";
    my $counter = 0;

    my $cached_id = 0;
    while(my($cluster_id, $cluster_name, $member)=$sth->fetchrow()) {

        $cluster_name ||= 'NoName'; # we need some name here however bogus (for formatting purposes)

        if($ncs->type() eq 'f') {
            $ncs->mname2clid($member, $cluster_id);
            $ncs->clid2clname($cluster_id, $cluster_name);
        } elsif($member) {
            $ncs->mname2clid($member, $cached_id);
        } else {
            $cached_id = $cluster_id;
            $ncs->clid2clname($cluster_id, $cluster_name);
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
    my ($self, $map, $dbh) = @_;

    my $step = 3000;

    my $sql = ($map->type eq 'f')
    ? qq{
        UPDATE family
        SET stable_id = ?, version = ?
        WHERE family_id = ?
    } : ($map->type eq 't')
    ? qq{
        REPLACE INTO protein_tree_stable_id(stable_id, version, node_id)
        VALUES (?, ?, ?)
    } : die "Cannot store mapping in database. Type must be either 'f' or 't'";
    my $sth = $dbh->prepare($sql);

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
    my ($self, $ncsl, $dbh, $timestamp, $master_dbh) = @_;
    
    my $mapping_session_id = $self->_get_mapping_session_id($ncsl, $timestamp, $dbh, $master_dbh);
    
    my $step = 2000;
    my $counter = 0;

    my $sth = $dbh->prepare(
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

sub _get_mapping_session_id {
  my ($self, $ncsl, $timestamp, $dbh, $master_dbh) = @_;
  
  $timestamp  ||= time();
  $master_dbh ||= $dbh;       # in case no master was given (so please provide the $master_dbh to avoid doing unnecessary work afterwards)
  
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
  
  my $ms_sth = $master_dbh->prepare( "INSERT INTO mapping_session(type, rel_from, rel_to, when_mapped, prefix) VALUES (?, ?, ?, FROM_UNIXTIME(?), ?)" );
  $ms_sth->execute($fulltype, $ncsl->from->release(), $ncsl->to->release(), $timestamp, $prefix);
  my $mapping_session_id = $ms_sth->{'mysql_insertid'};
  warn "newly generated mapping_session_id = '$mapping_session_id' for prefix '${prefix}'\n";
  $ms_sth->finish();

  if($dbh != $master_dbh) {   # replicate it in the release database:
      my $ms_sth2 = $dbh->prepare( "INSERT INTO mapping_session(mapping_session_id, type, rel_from, rel_to, when_mapped, prefix) VALUES (?, ?, ?, ?, FROM_UNIXTIME(?), ?)" );
      $ms_sth2->execute($mapping_session_id, $fulltype, $ncsl->from->release(), $ncsl->to->release(), $timestamp, $prefix);
      $ms_sth2->finish();
  }
  return $mapping_session_id;
}

sub store_tags {    # used to create cross-references from EnsEMBL GeneTrees to Treefam families
    my ($self, $accu, $dbh, $tag_prefix) = @_;

    $tag_prefix ||= '';

    my $step = 2000;
    
    my $sql = qq{ REPLACE INTO protein_tree_tag(node_id, tag, value) VALUES (?, ?, ?) };
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
  my $sql = 'select meta_value from meta where meta_key =? and species_id is null';
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
