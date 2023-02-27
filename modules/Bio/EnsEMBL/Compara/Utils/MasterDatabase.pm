=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 DESCRIPTION

This modules contains common methods used when dealing with the
Compara master database. They can in fact be called on other
databases too.

- update_dnafrags: updates the DnaFrags of a species

=cut

package Bio::EnsEMBL::Compara::Utils::MasterDatabase;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Exception qw(throw warning verbose);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::IO qw/:spurt/;

use Bio::EnsEMBL::Compara::Locus;
use Bio::EnsEMBL::Compara::Method;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor;
use Bio::EnsEMBL::Compara::Utils::Registry;

use Data::Dumper;
$Data::Dumper::Maxdepth=3;


=head2 update_dnafrags

  Arg[1]            : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]            : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Arg[3]            : Bio::EnsEMBL::DBSQL::DBAdaptor $species_dba
  Arg[COORD_SYSTEM] : (optional) only load Slices with $coord_system_name
  Description : This method fetches all the dnafrag in the compara DB
                corresponding to the $genome_db. It also gets the list
                of top_level seq_regions from the species core DB and
                updates the list of dnafrags in the compara DB.
  Returns     : Number of new DnaFrags
  Exceptions  : -none-

=cut

sub update_dnafrags {
    my $compara_dba = shift;
    my $genome_db   = shift;
    my $species_dba = shift;

    my($coord_system_name) = rearrange([qw(COORD_SYSTEM)], @_);
    $coord_system_name = 'toplevel' unless $coord_system_name;

    # fetch relevent slices from the core
    $species_dba = $genome_db->db_adaptor unless $species_dba;
    my $slices_it = Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor::iterate_toplevel_slices($species_dba, $genome_db->genome_component);
    die "Could not fetch any $coord_system_name slices from ".$genome_db->name() unless $slices_it->has_next();

    # fetch current dnafrags, to detect deprecations
    my $dnafrag_adaptor = $compara_dba->get_adaptor('DnaFrag');
    my $old_dnafrags = $dnafrag_adaptor->fetch_all_by_GenomeDB($genome_db, -COORD_SYSTEM_NAME => $coord_system_name);

    my ( $new_dnafrags_ids, $existing_dnafrags_ids, $deprecated_dnafrags, $species_overall_len ) = _load_dnafrags_from_slices($compara_dba, $genome_db, $slices_it, $old_dnafrags);

    # we only want to update this if we've imported toplevel frags
    _check_is_good_for_alignment($compara_dba, $genome_db, $species_overall_len) if $coord_system_name eq 'toplevel';

    $new_dnafrags_ids ||= 0;
    $existing_dnafrags_ids ||= 0;
    print "$existing_dnafrags_ids DnaFrags already in the database. Inserted $new_dnafrags_ids new DnaFrags.\n";

    _remove_deprecated_dnafrags($compara_dba, $deprecated_dnafrags);

    return $new_dnafrags_ids;
}

=head2 _load_dnafrags_from_slices

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Arg[3]      : Bio::EnsEMBL::Utils::Iterator of Bio::EnsEMBL::Slice $slices_it
  Arg[4]      : Arrayref of Bio::EnsEMBL::Compara::DnaFrag $old_dnafrags
  Description : This method fetches all the dnafrag in the compara DB
                corresponding to the $genome_db. It also gets the list
                of top_level seq_regions from the species core DB and
                updates the list of dnafrags in the compara DB.
  Returns     : Number of new DnaFrags
  Exceptions  : -none-

=cut

sub _load_dnafrags_from_slices {
    my ( $compara_dba, $genome_db, $slices_it, $old_dnafrags ) = @_;

    my $dnafrag_adaptor = $compara_dba->get_adaptor('DnaFrag');
    my $dnafrag_alt_adaptor = $compara_dba->get_adaptor('DnaFragAltRegion');
    my %old_dnafrags_by_name = map { $_->name => $_ } @$old_dnafrags;

    my ( $new_dnafrags_ids, $existing_dnafrags_ids, $species_overall_len );
    while (my $slice = $slices_it->next()) {
        my $new_dnafrag = Bio::EnsEMBL::Compara::DnaFrag->new_from_Slice($slice, $genome_db);

        push( @$species_overall_len, $new_dnafrag->length()) if $new_dnafrag->is_reference; # rule_2

        if (my $old_df = delete $old_dnafrags_by_name{$slice->seq_region_name}) {
            $new_dnafrag->dbID($old_df->dbID);
            $dnafrag_adaptor->update($new_dnafrag);
            $dnafrag_alt_adaptor->delete_by_dbID($new_dnafrag->dbID);
            $existing_dnafrags_ids++;

        } else {
            $dnafrag_adaptor->store($new_dnafrag);
            $new_dnafrags_ids++;
        }

        if (!$new_dnafrag->is_reference and ($new_dnafrag->coord_system_name ne 'lrg')) {
            my $alt_region = new_alt_region_for_Slice($slice, $new_dnafrag);
            $dnafrag_alt_adaptor->store_or_update($alt_region);
        }
    }
    # my @old_dnafrag_ids = map { $_->dbID } values %$old_dnafrags_by_name;
    my @old_dnafrags = values %old_dnafrags_by_name;

    return ( $new_dnafrags_ids, $existing_dnafrags_ids, \@old_dnafrags, $species_overall_len );
}

=head2 new_alt_region_for_Slice

  Arg[1]      : Bio::EnsEMBL::Slice $slice
  Arg[2]      : Bio::EnsEMBL::Compara::DnaFrag $dnafrag
  Description : Projects the slice onto the primary assembly, extracts the first
                and last positions where they differ, and returns the corresponding
                region as a Locus of the given dnafrag.
  Returntype  : Bio::EnsEMBL::Compara::Locus
  Exceptions  : Die if the DnaFrag is a reference one

=cut

sub new_alt_region_for_Slice {
    my ($slice, $dnafrag) = @_;

    my $start = $dnafrag->length;
    my $end   = 1;
    # Copied from Bio::EnsEMBL::DBSQL::SliceAdaptor
    my $projections = $slice->adaptor->fetch_normalized_slice_projection($slice);
    foreach my $segment (@$projections) {
        my $slice_part = $segment->[2];
        if ($slice_part->seq_region_name() eq $slice->seq_region_name() && $slice_part->coord_system->equals($slice->coord_system)) {
            $start = $slice_part->start if $slice_part->start < $start;
            $end   = $slice_part->end   if $slice_part->end   > $end;
        }
    }
    if ($start >= $end) {
        die "Non-reference slices are expected to differ from their original slices by more than 1 bp. Inspect " . $dnafrag->name;
    }
    return bless {
        'dnafrag'         => $dnafrag,
        'dnafrag_start'   => $start,
        'dnafrag_end'     => $end,
        'dnafrag_strand'  => 1,
    }, 'Bio::EnsEMBL::Compara::Locus';
}


=head2 _remove_deprecated_dnafrags

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : ArrayRef of DnaFrags
  Description : This method deletes DnaFrags with the given IDs from
                the compara database
  Returns     : -none-
  Exceptions  : -none-

=cut

sub _remove_deprecated_dnafrags {
    my ( $compara_dba, $dnafrags ) = @_;

    return if scalar(@$dnafrags) == 0;

    print 'Now deleting ', scalar(@$dnafrags), ' former DnaFrags...';
    my $dnafrag_adaptor = $compara_dba->get_DnaFragAdaptor;
    foreach my $deprecated_dnafrag (@$dnafrags) {
        $dnafrag_adaptor->delete($deprecated_dnafrag);
    }
    print "  ok!\n\n";

    my $delete_warning = "Removed " . scalar(@$dnafrags) . " dnafrags:\n\t";
    $delete_warning .= join( "\n\t", map { $_->name . '(' . $_->dbID . ')' } @$dnafrags ) . "\n";
    #die $delete_warning;
}


=head2 _check_is_good_for_alignment

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Arg[3]      : Bio::EnsEMBL::DBSQL::DBAdaptor $species_dba
  Description : This method fetches all the dnafrag in the compara DB
                corresponding to the $genome_db. It also gets the list
                of top_level seq_regions from the species core DB and
                updates the list of dnafrags in the compara DB.
  Returns     : Number of new DnaFrags
  Exceptions  : -none-

=cut

sub _check_is_good_for_alignment {
    my ($compara_dba, $genome_db, $species_lens) = @_;

    my @species_overall_len = @$species_lens;
    my $top_limit;
    if ( scalar(@species_overall_len) < 50 ) {
        $top_limit = scalar(@species_overall_len) - 1;
    }
    else {
        $top_limit = 49;
    }

    my @top_frags = ( sort { $b <=> $a } @species_overall_len )[ 0 .. $top_limit ];
    my @low_limit_frags = ( sort { $b <=> $a } @species_overall_len )[ ( $top_limit + 1 ) .. scalar(@species_overall_len) - 1 ];
    my $avg_top = _mean(@top_frags);

    my $ratio_top_highest = _sum(@top_frags)/_sum(@species_overall_len);

    #we set to 1 in case there are no values since we want to still compute the log
    my $avg_low;
    my $ratio_top_low;
    if ( scalar(@low_limit_frags) == 0 ) {

        #$ratio_top_low = 1;
        $avg_low = 1;
    }
    else {
        $avg_low = _mean(@low_limit_frags);
    }

    $ratio_top_low = $avg_top/$avg_low;

    my $log_ratio_top_low = log($ratio_top_low)/log(10);#rule_4

    undef @top_frags;
    undef @low_limit_frags;
    undef @species_overall_len;

    #After initially considering taking all the genomes that match cov >= 65% || log >= 3
    #We then decided to combine both variables and take all the genomes for
    #which log >= 10 - 3 * cov/25%. In other words, the classifier is a line that
    #passes by the (50%,4) and (75%,1) points. It excludes genomes that have a log
    #value >= 3 but a poor coverage, or a decent coverage but a low log value.
    #my $is_good_for_alignment = ($ratio_top_highest > 0.68) || ( $log_ratio_top_low > 3 ) ? 1 : 0;

    my $diagonal_cutoff = 10-3*($ratio_top_highest/0.25);

    my $is_good_for_alignment = ($log_ratio_top_low > $diagonal_cutoff) ? 1 : 0;

    my $sth = $compara_dba->dbc->prepare("UPDATE genome_db SET is_good_for_alignment = ? WHERE name = ? AND assembly = ?");
    $sth->execute($is_good_for_alignment,$genome_db->name(),$genome_db->assembly);
    $sth->finish;
}


############################################################
#                 update_genome.pl methods                 #
############################################################

=head2 update_genome

  Arg[1]      : string $species_name
  Arg[2]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[3]      : (optional) boolean $release
  Arg[4]      : (optional) boolean $force
  Arg[5]      : (optional) int $taxon_id
  Arg[6]      : (optional) int $offset
  Description : Does everything for this species: create / update the GenomeDB entry, and load the DnaFrags.
  				To set the new species as current, set $release = 1. If the GenomeDB already exists, set $force = 1
  				to force the update of DnaFrags. Use $taxon_id to manually set the taxon id for this species (default
  				is to find it in the core db). $offset can be used to override autoincrement of dbID
  Returns     : arrayref containing (1) new Bio::EnsEMBL::Compara::GenomeDB object, (2) arrayref of updated
                component GenomeDBs, (3) number of dnafrags updated
  Exceptions  : none

=cut

sub update_genome {
    # my ($compara_dba, $species, $release, $force, $taxon_id, $offset) = @_;
    # my $self = shift;
    my $compara_dba = shift;
    my $species = shift;

    my($release, $force, $taxon_id, $offset) = rearrange([qw(RELEASE FORCE TAXON_ID OFFSET)], @_);

    my $species_no_underscores = $species;
    $species_no_underscores =~ s/\_/\ /;

    my $species_db = Bio::EnsEMBL::Registry->get_DBAdaptor($species, "core");
    if(! $species_db) {
        $species_db = Bio::EnsEMBL::Registry->get_DBAdaptor($species_no_underscores, "core");
    }
    throw ("Cannot connect to database [${species_no_underscores} or ${species}]") if (!$species_db);

    my ( $new_genome_db, $component_genome_dbs, $new_dnafrags );
    my $gdbs = $compara_dba->dbc->sql_helper->transaction( -CALLBACK => sub {
        $new_genome_db = _update_genome_db($species_db, $compara_dba, $release, $force, $taxon_id, $offset);
        print "GenomeDB after update: ", $new_genome_db->toString, "\n\n";
        print "Fetching DnaFrags from " . $species_db->dbc->host . "/" . $species_db->dbc->dbname . "\n";
        $new_dnafrags = update_dnafrags($compara_dba, $new_genome_db, $species_db);
        $component_genome_dbs = _update_component_genome_dbs($new_genome_db, $species_db, $compara_dba);
        foreach my $component_gdb (@$component_genome_dbs) {
            $new_dnafrags += update_dnafrags($compara_dba, $component_gdb, $species_db);
        }
        print_method_link_species_sets_to_update_by_genome_db($compara_dba, $new_genome_db);
        # return [$new_genome_db, $component_genome_dbs, $new_dnafrags];
    } );
    $species_db->dbc()->disconnect_if_idle();
    return [$new_genome_db, $component_genome_dbs, $new_dnafrags];
}


=head2 _update_genome_db

  Arg[1]      : Bio::EnsEMBL::DBSQL::DBAdaptor $species_dba
  Arg[2]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[3]      : (optional) boolean $release
  Arg[4]      : (optional) boolean $force
  Arg[5]      : (optional) int $taxon_id
  Arg[6]      : (optional) int $offset
  Description : This method takes all the information needed from the
                species database in order to update the genome_db table
                of the compara database
  Returns     : The new Bio::EnsEMBL::Compara::GenomeDB object
  Exceptions  : throw if the genome_db table is up-to-date unless the
                --force option has been activated

=cut

sub _update_genome_db {
  my ($species_dba, $compara_dba, $release, $force, $taxon_id, $offset) = @_;

  my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();
  my $genome_db = eval {$genome_db_adaptor->fetch_by_core_DBAdaptor($species_dba)};

  if ($genome_db and $genome_db->dbID) {
    if (not $force) {
      my $species_production_name = $genome_db->name;
      my $this_assembly = $genome_db->assembly;
      print $genome_db->toString, "\n";
      my ($match, $output);
      {
        # dnafrags_match_core_slices uses print. This is to capture the output
        local *STDOUT;
        open (STDOUT, '>', \$output);
        $match = dnafrags_match_core_slices($genome_db, $species_dba);
      }
      my $msg = "\n\n** GenomeDB with this name [$species_production_name] and assembly".
        " [$this_assembly] is already in the compara DB **\n";
      if ($match) {
        $msg .= "** And it has the right set of DnaFrags **\n";
        $msg .= "** You can use the --force option to update the other GenomeDB fields IF YOU REALLY NEED TO!! **\n\n";
      } else {
        $msg .= "** But the DnaFrags don't match: **\n$output\n";
        $msg .= "** You can use the --force option to update the DnaFrag, but only IF YOU REALLY KNOW WHAT YOU ARE DOING!! **\n\n";
      }
      throw $msg;
    }
  }

  if ($genome_db) {
    print "GenomeDB before update: ", $genome_db->toString, "\n";

    # Get fresher information from the core database
    $genome_db->db_adaptor($species_dba, 1);
    $genome_db->last_release(undef);

    # And store it back in Compara
    $genome_db_adaptor->update($genome_db);
  } else { # new genome or new assembly!!
    $genome_db = Bio::EnsEMBL::Compara::GenomeDB->new_from_DBAdaptor($species_dba);
    $genome_db->taxon_id( $taxon_id ) if $taxon_id;

    if (!defined($genome_db->name)) {
      throw "Cannot find species.production_name in meta table for ".($species_dba->locator).".\n";
    }
    if (!defined($genome_db->taxon_id)) {
      throw "Cannot find species.taxonomy_id in meta table for ".($species_dba->locator).".\n".
          "   You can use the --taxon_id option";
    }
    print "New GenomeDB for Compara: ", $genome_db->toString, "\n";

    # new ID search if $offset is true
    if($offset) {
        my ($max_id) = $compara_dba->dbc->db_handle->selectrow_array('select max(genome_db_id) from genome_db where genome_db_id > ?', undef, $offset);
    	$max_id = $offset unless $max_id;
	    $genome_db->dbID($max_id + 1);
    }
    $genome_db_adaptor->store($genome_db);
  }

  $genome_db_adaptor->make_object_current($genome_db) if $release;
  return $genome_db;
}


=head2 _update_component_genome_dbs

  Description : Updates all the genome components (only for polyploid genomes)
  Returns     : -none-
  Exceptions  : none

=cut

sub _update_component_genome_dbs {
    my ($principal_genome_db, $species_dba, $compara_dba) = @_;

    my @gdbs;
    my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();
    foreach my $c (@{$species_dba->get_GenomeContainer->get_genome_components}) {
        my $copy_genome_db = $principal_genome_db->make_component_copy($c);
        $genome_db_adaptor->store($copy_genome_db);
        push @gdbs, $copy_genome_db;
        print "Component '$c' genome_db:\n\t", $copy_genome_db->toString(), "\n";
    }
    return \@gdbs;
}

=head2 list_assembly_patches

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Description : This method lists the new assembly patches from the core database
  Returns     : -none-
  Exceptions  :

=cut

sub list_assembly_patches {
    my $compara_dba = shift;    # Pointer to the *previous* database, in order to get the deprecated dnafrag_ids
    my $genome_db   = shift;
    my $report_file = shift;

    die "Patches are only available for GRC species" unless $genome_db->assembly =~ /^GRC/;
    my $find_patches_sql = "SELECT s.name, s.seq_region_id, a.value FROM seq_region s JOIN seq_region_attrib a USING(seq_region_id) JOIN attrib_type t USING(attrib_type_id) WHERE t.code IN ('patch_fix', 'patch_novel')";

    my $species_db = $genome_db->db_adaptor;
    my $curr_patches_sth = $species_db->dbc->prepare($find_patches_sql);
    $curr_patches_sth->execute;
    my $curr_patches = $curr_patches_sth->fetchall_arrayref;
    $curr_patches_sth->finish;
    my @curr_patches_seq_region_ids = map { $_->[1] } @$curr_patches;
    my %curr_patches_by_name = map { $_->[0] => {seq_region_id => $_->[1], date => $_->[2]} } @$curr_patches;

    my $prev_species_db = Bio::EnsEMBL::Compara::Utils::Registry::get_previous_core_DBAdaptor($genome_db->name);
    my $prev_genome_db = $compara_dba->get_GenomeDBAdaptor->fetch_by_core_DBAdaptor($prev_species_db);
    my $prev_patches_sth = $prev_species_db->dbc->prepare($find_patches_sql);
    $prev_patches_sth->execute;
    my $prev_patches = $prev_patches_sth->fetchall_arrayref;
    $prev_patches_sth->finish;
    my %prev_patches_by_name = map { $_->[0] => {seq_region_id => $_->[1], date => $_->[2]} } @$prev_patches;

    # now detect the differences and choose the appropriate action:
    # 1. deleted patches (present in prev, not present in curr) = add dnafrag to deprecated list
    # 2. changed patches (present in both, but dates differ) = add dnafrag to depr list && add slice to load patch list
    # 3. new patches (not present in prev, present in curr) = add slice to load patch list
    my $dnafrag_adaptor = $compara_dba->get_DnaFragAdaptor;
    my @depr_patch_dnafrags;
    my ( @new_patches, @changed_patches, @deleted_patches ); # store names for reports only
    foreach my $patch_name ( keys %prev_patches_by_name ) {
        if ( !defined $curr_patches_by_name{$patch_name} ) {
            push @deleted_patches, $patch_name;
            my $deleted_patch_dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name($prev_genome_db, $patch_name);
            push @depr_patch_dnafrags, $deleted_patch_dnafrag;
        } elsif ( $curr_patches_by_name{$patch_name}->{date} ne $prev_patches_by_name{$patch_name}->{date} ) {
            push @changed_patches, $patch_name;
            my $changed_patch_dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name($prev_genome_db, $patch_name);
            push @depr_patch_dnafrags, $changed_patch_dnafrag;
        }
    }
    foreach my $patch_name ( keys %curr_patches_by_name ) {
        if ( !defined $prev_patches_by_name{$patch_name} ) {
            push @new_patches, $patch_name;
        }
    }

    my $report = "No patch updates found\n";
    if ( @new_patches || @changed_patches || @deleted_patches ) {
        $report = "New patches:\n" . join("\n", @new_patches) . "\n\n";
        $report .= "Changed patches:\n" . join("\n", @changed_patches) . "\n\n";
        $report .= "Deleted patches: \n" . join("\n", @deleted_patches) . "\n\n";
        $report .= "----------------------------------------------------\n";
        $report .= "Patch dnafrag_ids that have been removed:\n";
        $report .= join( "\n", map { $_->dbID } @depr_patch_dnafrags ) . "\n";
        $report .= "----------------------------------------------------\n";
        if ( @new_patches || @changed_patches ) {
            $report .= "Input for create_patch_pairaligner_conf.pl:\n--patches chromosome:";
            $report .= join( ",chromosome:", (@new_patches, @changed_patches) ) . "\n" ;
        }
    }

    if ( $report_file ) {
        spurt($report_file, $report);
        print STDERR "Assembly patch report written to $report_file\n";
    } else {
        print $report;
    }
}

=head2 print_method_link_species_sets_to_update_by_genome_db

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Description : This method prints all the genomic MethodLinkSpeciesSet
                that need to be updated (those which correspond to the
                $genome_db).
                NB: Only method_link with a dbID<200 || dbID>=500 are taken into
                account (they should be the genomic ones)
  Returns     : -none-
  Exceptions  :

=cut

sub print_method_link_species_sets_to_update_by_genome_db {
  my ($compara_dba, $genome_db, $release) = @_;

  my $method_link_species_set_adaptor = $compara_dba->get_adaptor("MethodLinkSpeciesSet");
  my $genome_db_adaptor = $compara_dba->get_adaptor("GenomeDB");

  my @these_gdbs;


  my $method_link_species_sets;
  my $mlss_found = 0;
  # foreach my $this_genome_db (@{$genome_db_adaptor->fetch_all()}) {
  #   next if ($this_genome_db->name ne $genome_db->name);
  my $this_genome_db = _prev_genome_db($compara_dba, $genome_db);
  return unless $this_genome_db;
    foreach my $this_method_link_species_set (@{$method_link_species_set_adaptor->fetch_all_by_GenomeDB($this_genome_db)}) {
      next unless $this_method_link_species_set->is_current || $release;
      $mlss_found = 1;
      $method_link_species_sets->{$this_method_link_species_set->method->dbID}->
          {join("-", sort map {$_->name} @{$this_method_link_species_set->species_set->genome_dbs})} = $this_method_link_species_set;
    }
  # }

  return unless $mlss_found;

  print "List of Bio::EnsEMBL::Compara::MethodLinkSpeciesSet to update:\n" if ! $release;
  print "List of Bio::EnsEMBL::Compara::MethodLinkSpeciesSet retired:\n" if $release;
  foreach my $this_method_link_id (sort {$a <=> $b} keys %$method_link_species_sets) {
    next if ($this_method_link_id > 200) and ($this_method_link_id < 500); # Avoid non-genomic method_link_species_set
    foreach my $this_method_link_species_set (values %{$method_link_species_sets->{$this_method_link_id}}) {
      printf "%8d: ", $this_method_link_species_set->dbID,;
      print $this_method_link_species_set->method->type, " (", $this_method_link_species_set->name, ")\n";
    }
  }

}

=head2 _prev_genome_db

	Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
	Arg[2]      : Bio::EnsEMBL::Compara::GenomeDB $gdb
	Description : Find the GenomeDB object that $gdb has succeeded
	Returns     : Bio::EnsEMBL::Compara::GenomeDB

=cut

sub _prev_genome_db {
    my ($compara_dba, $gdb) = @_;

    my $genome_db_adaptor = $compara_dba->get_adaptor("GenomeDB");

    my $prev_gdb;
    my @this_species_gdbs = sort { $a->first_release <=> $b->first_release } grep { $_->name eq $gdb->name && $_->dbID != $gdb->dbID && defined $gdb->first_release } @{$genome_db_adaptor->fetch_all()};
    return undef unless scalar @this_species_gdbs >= 1;
    return pop @this_species_gdbs;
}

############################################################
#                edit_collection.pl methods                #
############################################################

=head2 new_collection

	Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
	Arg[2]      : string $collection_name
	Arg[3]      : arrayref $species_names
	Arg[4]      : boolean $dry_run
	Description : Create a new collection species set from the given list of species
	              names (most recent assemblies). To perform the operation WITHOUT
	              storing to the database, set $dry_run = 1
	Returns     : Bio::EnsEMBL::Compara::SpeciesSet

=cut

sub new_collection {
    # my ( $compara_dba, $collection_name, $species_names, $dry_run ) = @_;
    my $compara_dba = shift;
    my $collection_name = shift;
    my $species_names = shift;
    my($release, $dry_run, $incl_components) = rearrange([qw(RELEASE DRY_RUN INCL_COMPONENTS)], @_);


    my $ss_adaptor = $compara_dba->get_SpeciesSetAdaptor;
    my $collection_ss;

    my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor;
    my @new_collection_gdbs = map {$genome_db_adaptor->_find_most_recent_by_name($_)} @$species_names;
    @new_collection_gdbs = _expand_components(\@new_collection_gdbs) if $incl_components;

    my $new_collection_ss;
    $compara_dba->dbc->sql_helper->transaction( -CALLBACK => sub {
        $new_collection_ss = $ss_adaptor->update_collection($collection_name, \@new_collection_gdbs, $release);
        die "\n\n*** Dry-run mode requested. No changes were made to the database ***\n\nThe following collection WOULD have been created:\n" . $new_collection_ss->toString . "\n\n" if $dry_run;
        print "\nStored: " . $new_collection_ss->toString . "\n\n";
    } );

    return $new_collection_ss;
}

=head2 update_collection

	Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
	Arg[2]      : string $collection_name
	Arg[3]      : arrayref $species_names
	Arg[4]      : boolean $dry_run
	Description : Create a new collection species set from the given list of species
	              names (most recent assemblies). To perform the operation WITHOUT
	              storing to the database, set $dry_run = 1
	Returns     : Bio::EnsEMBL::Compara::SpeciesSet

=cut

sub update_collection {
    # my ( $compara_dba, $collection_name, $species_names ) = @_;
    my $compara_dba = shift;
    my $collection_name = shift;
    my $species_names = shift;
    my($release, $dry_run, $incl_components) = rearrange([qw(RELEASE DRY_RUN INCL_COMPONENTS)], @_);

    my $ss_adaptor = $compara_dba->get_SpeciesSetAdaptor;
    my $collection_ss;

    my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor;
    my @requested_species_gdbs = map {$genome_db_adaptor->_find_most_recent_by_name($_)} @$species_names;

    my @new_collection_gdbs = @requested_species_gdbs;
    $collection_ss = $ss_adaptor->fetch_collection_by_name($collection_name);
    warn "Adding species to collection '$collection_name' (dbID: " . $collection_ss->dbID . ")\n";

    my @gdbs_in_current_collection = @{$collection_ss->genome_dbs};
    my %collection_species_by_name = (map {$_->name => $_} @gdbs_in_current_collection);

    foreach my $coll_gdb ( @gdbs_in_current_collection ) {
        # if this species already exists in the collection, skip it as we've already added the newest assembly
        my $name_match_gdb = grep { $coll_gdb->name eq $_->name } @requested_species_gdbs;
        next if $name_match_gdb == 1;

        if ( $name_match_gdb ) {
        	print Dumper $name_match_gdb;
            warn "Replaced " . $coll_gdb->name . " assembly " . $coll_gdb->assembly . " with " . $name_match_gdb->assembly . "\n";
        } else {
            push( @new_collection_gdbs, $coll_gdb );
        }
    }
    @new_collection_gdbs = _expand_components(\@new_collection_gdbs) if $incl_components;

    my $new_collection_ss;
    $compara_dba->dbc->sql_helper->transaction( -CALLBACK => sub {
        $new_collection_ss = $ss_adaptor->update_collection($collection_name, \@new_collection_gdbs, $release);

        print_method_link_species_sets_to_update_by_collection($compara_dba, $collection_ss);
        die "\n\n*** Dry-run mode requested. No changes were made to the database ***\n\nThe following collection WOULD have been created:\n" . $new_collection_ss->toString . "\n\n" if $dry_run;
        print "\nStored: " . $new_collection_ss->toString . "\n\n";
    } );

    return $new_collection_ss;
}


=head2 _expand_components

  Arg[1]      : Arrayref of GenomeDBs
  Description : expand a list of GenomeDBs to include the component GenomeDBs
  Returns     : Array of GenomeDBs (same as input if no polyploid genomes are passed)

=cut

sub _expand_components {
    my $genome_dbs = shift;
    my @expanded_gdbs;
    foreach my $gdb ( @$genome_dbs ) {
        push @expanded_gdbs, $gdb;
        my $components = $gdb->component_genome_dbs;
        push @expanded_gdbs, @$components if scalar @$components > 0;
    }
    return @expanded_gdbs;
}

=head2 print_method_link_species_sets_to_update_by_collection

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : Bio::EnsEMBL::Compara::SpeciesSet $collection_ss
  Description : This method prints all the genomic MethodLinkSpeciesSet
                that need to be updated (those which correspond to the
                $collection_ss species-set).
  Returns     : -none-
  Exceptions  :

=cut

sub print_method_link_species_sets_to_update_by_collection {
    my ($compara_dba, $collection_ss) = @_;

    my $method_link_species_sets = $compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_all_by_species_set_id($collection_ss->dbID);

    return unless $method_link_species_sets->[0];

    print "List of Bio::EnsEMBL::Compara::MethodLinkSpeciesSet to update:\n";
    foreach my $this_method_link_species_set (sort {$a->dbID <=> $b->dbID} @$method_link_species_sets) {
        printf "%8d: ", $this_method_link_species_set->dbID,;
        print $this_method_link_species_set->method->type, " (", $this_method_link_species_set->name, ")\n";
        if ($this_method_link_species_set->url) {
            $this_method_link_species_set->url('');
            $compara_dba->dbc->do('UPDATE method_link_species_set SET url = "" WHERE method_link_species_set_id = ?', undef, $this_method_link_species_set->dbID);
        }
    }
    print "  NONE\n" unless scalar(@$method_link_species_sets);

}

sub create_species_set {
    my ($genome_dbs, $species_set_name, $no_release) = @_;

    $no_release //= 0;
    $species_set_name ||= join('-', sort map {$_->get_short_name} @{$genome_dbs});
    my $species_set = Bio::EnsEMBL::Compara::SpeciesSet->new(
        -GENOME_DBS => $genome_dbs,
        -NAME => $species_set_name,
    );
    $species_set->{_no_release} = $no_release;
    return $species_set;
}

sub create_mlss {
    my ($method, $species_set, $source, $url) = @_;
    if (ref($species_set) eq 'ARRAY') {
        $species_set = create_species_set($species_set);
    }
    my $ss_display_name = $species_set->get_value_for_tag('display_name');
    {
        $ss_display_name ||= $species_set->name;
        $ss_display_name =~ s/collection-//;
        my $ss_size = $species_set->size;
        my $is_aln = $method->class =~ /^(GenomicAlign|ConstrainedElement|ConservationScore|Synteny)/;
        $ss_display_name = "$ss_size $ss_display_name" if $is_aln && $ss_size > 2;
    }
    my $mlss_name = sprintf('%s %s', $ss_display_name, $method->display_name || die "No description for ".$method->type);
    return Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
        -SPECIES_SET => $species_set,
        -METHOD => $method,
        -NAME => $mlss_name,
        -SOURCE => $source || 'ensembl',
        -URL => $url,
    );
}

sub create_mlsss_on_singletons {
    my ($method, $genome_dbs) = @_;
    return [map {create_mlss($method, [$_])} @$genome_dbs];
}

sub create_mlsss_on_pairs {
    my ($method, $genome_dbs, $source, $url) = @_;
    my @mlsss;
    my @input_genome_dbs = @$genome_dbs;
    while (my $gdb1 = shift @input_genome_dbs) {
        foreach my $gdb2 (@input_genome_dbs) {
            push @mlsss, create_mlss($method, [$gdb1, $gdb2], undef, $source, $url);
        }
    }
    return \@mlsss;
}

sub create_self_wga_mlsss {
    my ($compara_dba, $gdb) = @_;
    my $species_set = create_species_set([$gdb]);

    # Alignment with LASTZ_NET (for now ... we may turn this into a parameter in the future)
    my $aln_method = $compara_dba->get_MethodAdaptor->fetch_by_type('LASTZ_NET');
    my $self_lastz_mlss = create_mlss($aln_method, $species_set);
    $self_lastz_mlss->add_tag( 'species_set_size', 1 );
    $self_lastz_mlss->name( $self_lastz_mlss->name . ' (self-alignment)' );

    if ($gdb->is_polyploid) {
        # POLYPLOID is the restriction of the alignment on the homoeologues
        my $pp_method = $compara_dba->get_MethodAdaptor->fetch_by_type('POLYPLOID');
        my $pp_mlss = create_mlss($pp_method, $species_set);
        return [$self_lastz_mlss, $pp_mlss];
    }
    return [$self_lastz_mlss];
}

sub create_pairwise_wga_mlsss {
    my ($compara_dba, $method, $ref_gdb, $nonref_gdb) = @_;
    my @mlsss;
    my $species_set = create_species_set([$ref_gdb, $nonref_gdb]);
    my $pw_mlss = create_mlss($method, $species_set);
    $pw_mlss->add_tag( 'reference_species', $ref_gdb->name );
    $pw_mlss->name( $pw_mlss->name . sprintf(' (on %s)', $ref_gdb->get_short_name) );
    push @mlsss, $pw_mlss;
    if ($ref_gdb->has_karyotype and $nonref_gdb->has_karyotype) {
        my $synt_method = $compara_dba->get_MethodAdaptor->fetch_by_type('SYNTENY');
        push @mlsss, create_mlss($synt_method, $species_set);
    }
    return \@mlsss;
}

sub create_multiple_wga_mlsss {
    my ($compara_dba, $method, $species_set, $with_gerp, $no_release, $source, $url) = @_;

    my @mlsss;
    push @mlsss, create_mlss($method, $species_set, $source, $url);
    if ($with_gerp) {
        my $ce_method = $compara_dba->get_MethodAdaptor->fetch_by_type('GERP_CONSTRAINED_ELEMENT');
        push @mlsss, create_mlss($ce_method, $species_set, $source, $url);
        my $cs_method = $compara_dba->get_MethodAdaptor->fetch_by_type('GERP_CONSERVATION_SCORE');
        push @mlsss, create_mlss($cs_method, $species_set, $source, $url);
    }
    if ($method->type eq 'CACTUS_HAL') {
        my $pw_method = $compara_dba->get_MethodAdaptor->fetch_by_type('CACTUS_HAL_PW');
        push @mlsss, @{ create_mlsss_on_pairs($pw_method, $species_set->genome_dbs, $source, $url) };
    } 
    
    if ( $no_release ) {
        foreach my $mlss ( @mlsss ) {
            $mlss->{_no_release} = $no_release;
        }
    }
       
    return \@mlsss;
}

sub create_assembly_patch_mlsss {
    my ($compara_dba, $genome_db) = @_;
    my $species_set = create_species_set([$genome_db]);
    my @mlsss;
    foreach my $method_type (qw(LASTZ_PATCH ENSEMBL_PROJECTIONS)) {
        my $method = $compara_dba->get_MethodAdaptor->fetch_by_type($method_type);
        push @mlsss, create_mlss($method, $species_set);
    }
    return \@mlsss,
}

sub create_homology_mlsss {
    my ($compara_dba, $method, $species_set) = @_;
    my @mlsss;
    push @mlsss, create_mlss($method, $species_set);
    if (($method->type eq 'PROTEIN_TREES') or ($method->type eq 'NC_TREES')) {
        my @non_components = grep {!$_->genome_component} @{$species_set->genome_dbs};
        my $orth_method = $compara_dba->get_MethodAdaptor->fetch_by_type('ENSEMBL_ORTHOLOGUES');
        push @mlsss, @{ create_mlsss_on_pairs($orth_method, \@non_components) };
        my $para_method = $compara_dba->get_MethodAdaptor->fetch_by_type('ENSEMBL_PARALOGUES');
        push @mlsss, @{ create_mlsss_on_singletons($para_method, \@non_components) };
        my $homoeo_method = $compara_dba->get_MethodAdaptor->fetch_by_type('ENSEMBL_HOMOEOLOGUES');
        foreach my $gdb (@{$species_set->genome_dbs}) {
            push @mlsss, create_mlss($homoeo_method, [$gdb]) if $gdb->is_polyploid;
        }
    }
    return \@mlsss;
}

sub _sum {
    my (@items) = @_;
    my $res;
    for my $next (@items) {
        die unless ( defined $next );
        $res += $next;
    }
    return $res;
}

sub _mean {
    my (@items) = @_;
    return _sum(@items)/( scalar @items );
}

=head2 dnafrags_match_core_slices

    Arg[1]      : Bio::EnsEMBL::Compara::GenomeDB $genome_db
    Arg[2]      : Bio::EnsEMBL::DBSQL::DBAdaptor $species_dba (optional)
    Description : This method compares the given $genome_db DnaFrags (names,
                  coordinate systems and lengths) with the toplevel Slices from
                  its corresponding core database.
    Returns     : 1 upon match; 0 upon mismatch
    Exceptions  :

=cut

sub dnafrags_match_core_slices {
    my ($genome_db, $species_dba) = @_;

    $species_dba //= $genome_db->db_adaptor;
    my $gdb_slices  = $genome_db->genome_component
        ? $species_dba->get_SliceAdaptor->fetch_all_by_genome_component($genome_db->genome_component)
        : $species_dba->get_SliceAdaptor->fetch_all('toplevel', undef, 1, 1, 1);
    my %slices = map { $_->seq_region_name => $_ } @$gdb_slices;

    my $dnafrag_adaptor = $genome_db->adaptor->db->get_DnaFragAdaptor;
    my $gdb_dnafrags = $dnafrag_adaptor->fetch_all_by_GenomeDB($genome_db);
    my %dnafrags = map { $_->name => $_ } @$gdb_dnafrags;

    my (@missing_dnafrags, @differing_dnafrags);
    foreach my $s_name ( keys %slices ) {
        if (defined $dnafrags{$s_name}) {
            if ( ($dnafrags{$s_name}->length != $slices{$s_name}->seq_region_length) ||
                 ($dnafrags{$s_name}->coord_system_name ne $slices{$s_name}->coord_system->name) ) {
                push( @differing_dnafrags, $s_name );
            }
        } else {
            push( @missing_dnafrags, $s_name );
        }
    }

    my (@missing_slices);
    foreach my $d_name ( keys %dnafrags ) {
        # Differing slices will be the same as differing dnafrags, so there is no need to check it again
        if (! defined $slices{$d_name}) {
            push( @missing_slices, $d_name );
        }
    }

    if ( @missing_dnafrags || @missing_slices || @differing_dnafrags ) {
        if ( @missing_dnafrags ) {
            print scalar @missing_dnafrags . " slices found in core db, but missing dnafrags in compara db:\n\t";
            print join( "\n\t", @missing_dnafrags ) . "\n\n";
        }
        if ( @missing_slices ) {
            print scalar @missing_slices . " dnafrags found in compara db, but missing slices in core db:\n\t";
            print join( "\n\t", @missing_slices ) . "\n\n";
        }
        if ( @differing_dnafrags ) {
            print scalar @differing_dnafrags . " dnafrags differ from their core counterparts:\n";
            foreach my $d_name ( @differing_dnafrags ) {
                print "\t$d_name\n\t\tlengths: compara=" . ($dnafrags{$d_name}->length || 'NA') . ", core=" . ($slices{$d_name}->seq_region_length || 'NA') . "\n" .
                      "\t\tcoordinate system names: compara=" . ($dnafrags{$d_name}->coord_system_name || 'NA') . ", core=" . ($slices{$d_name}->coord_system->name || 'NA') . "\n";
            }
        }

        return 0;
    } else {
        return 1;
    }
}

1;
