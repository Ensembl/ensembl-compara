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

=cut

=head1 NAME

Bio::EnsEMBL::Compara::MethodLinkSpeciesSet

=head1 DESCRIPTION

Relates every method_link with the species_set for which it has been used.

=head1 SYNOPSIS

  use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
  my $method_link_species_set = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
                       -adaptor             => $method_link_species_set_adaptor,
                       -method              => Bio::EnsEMBL::Compara::Method->new( -type => 'MULTIZ'),
                       -species_set     => Bio::EnsEMBL::Compara::SpeciesSet->new( -genome_dbs => [$gdb1, $gdb2, $gdb3]),
                       -max_alignment_length => 10000,
                   );

SET VALUES
  $method_link_species_set->dbID( 12 );
  $method_link_species_set->adaptor( $mlss_adaptor );
  $method_link_species_set->method( Bio::EnsEMBL::Compara::Method->new( -type => 'MULTIZ') );
  $method_link_species_set->species_set( Bio::EnsEMBL::Compara::SpeciesSet->new( -genome_dbs => [$gdb1, $gdb2, $gdb3]) );
  $method_link_species_set->max_alignment_length( 10000 );

GET VALUES
  my $mlss_id           = $method_link_species_set->dbID();
  my $mlss_adaptor      = $method_link_species_set->adaptor();
  my $method            = $method_link_species_set->method();
  my $method_link_id    = $method_link_species_set->method->dbID();
  my $method_link_type  = $method_link_species_set->method->type();
  my $species_set       = $method_link_species_set->species_set();
  my $species_set_id    = $method_link_species_set->species_set->dbID();
  my $genome_dbs        = $method_link_species_set->species_set->genome_dbs();
  my $max_alignment_length = $method_link_species_set->max_alignment_length();

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_).

=cut

package Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Scalar qw(:assert);

use Bio::EnsEMBL::Compara::Method;
use Bio::EnsEMBL::Compara::SpeciesSet;

use base (  'Bio::EnsEMBL::Compara::StorableWithReleaseHistory',           # inherit dbID(), adaptor() and new() methods, and first_release() and last_release()
            'Bio::EnsEMBL::Compara::Taggable'   # inherit everything related to tagability
         );

my $DEFAULT_MAX_ALIGNMENT = 20000;


=head2 new (CONSTRUCTOR)

  Arg [-DBID]           : (opt.) int $dbID (the database internal ID for this object)
  Arg [-ADAPTOR]        : (opt.) Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor $adaptor
                            (the adaptor for connecting to the database)
  Arg [-METHOD]         : Bio::EnsEMBL::Compara::Method $method object
  Arg [-SPECIES_SET]    : Bio::EnsEMBL::Compara::SpeciesSet $species_set object
  Arg [-NAME]           : (opt.) string $name (the name for this method_link_species_set)
  Arg [-SOURCE]         : (opt.) string $source (the source of these data)
  Arg [-URL]            : (opt.) string $url (the original url of these data)
  Arg [-MAX_ALGINMENT_LENGTH]
                        : (opt.) int $max_alignment_length (the length of the largest alignment
                            for this MethodLinkSpeciesSet (only used for genomic alignments)
  Example     : my $method_link_species_set = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
                       -adaptor => $method_link_species_set_adaptor,
                       -method => Bio::EnsEMBL::Compara::Method->new( -type => 'MULTIZ' ),
                       -species_set => Bio::EnsEMBL::Compara::SpeciesSet->new( -genome_dbs => [$gdb1, $gdb2, $gdb3] ),
                       -max_alignment_length => 10000,
                   );
  Description : Creates a new MethodLinkSpeciesSet object
  Returntype  : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Exceptions  : none
  Caller      : general

=cut

sub new {
    my $caller = shift @_;
    my $class = ref($caller) || $caller;

    my $self = $class->SUPER::new(@_);  # deal with Storable stuff

    my ($method, $species_set,
        $name, $source, $url, $max_alignment_length) =
            rearrange([qw(
                METHOD SPECIES_SET
                NAME SOURCE URL MAX_ALIGNMENT_LENGTH)], @_);

  if($method) {
      $self->method($method);
  } else {
      warning("method has not been set in MLSS->new");
  }

  if ($species_set) {
      $self->species_set($species_set);
  } else {
      warning("species_set has not been set in MLSS->new");
  }

  $self->name($name) if (defined ($name));
  $self->source($source) if (defined ($source));
  $self->url($url) if (defined ($url));
  $self->max_alignment_length($max_alignment_length) if (defined ($max_alignment_length));

  return $self;
}



=head2 method

  Arg [1]    : (opt.) Bio::EnsEMBL::Compara::Method object
  Example    : my $method_object = $method_link_species_set->method();
  Example    : $method_link_species_set->method( $method_object );
  Description: get/set for attribute method
  Returntype : Bio::EnsEMBL::Compara::Method
  Exceptions : none
  Caller     : general

=cut

sub method {
    my ($self, $method) = @_;

    if($method) {
        if(ref($method) eq 'HASH') {
            $method = Bio::EnsEMBL::Compara::Method->new( %$method ) or die "Could not automagically create a Method\n";
        }

        $self->{'method'} = $method;
    }

    return $self->{'method'};
}


=head2 species_set

  Arg [1]    : (opt.) Bio::EnsEMBL::Compara::SpeciesSet species_set object
  Example    : my $species_set = $mlss->species_set();
  Example    : $mlss->species_set( $species_set );
  Description: getter/setter for species_set attribute
  Returntype : Bio::EnsEMBL::Compara::SpeciesSet
  Exceptions : none
  Caller     : general

=cut

sub species_set {
    my ($self, $species_set) = @_;

    if($species_set) {
        if(ref($species_set) eq 'HASH') {
            $species_set = Bio::EnsEMBL::Compara::SpeciesSet->new( %$species_set ) or die "Could not automagically create a SpeciesSet\n";
        }

        $self->{'species_set'} = $species_set;
    }

    return $self->{'species_set'};
}




=head2 name

  Arg [1]    : (opt.) string $name
  Example    : my $name = $method_link_species_set->name();
  Example    : $method_link_species_set->name("families");
  Description: get/set for attribute name
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub name {
  my ($self, $arg) = @_;

  if (defined($arg)) {
    $self->{'name'} = $arg ;
  }

  return $self->{'name'};
}


=head2 source

  Arg [1]    : (opt.) string $name
  Example    : my $name = $method_link_species_set->source();
  Example    : $method_link_species_set->source("ensembl");
  Description: get/set for attribute source. The source refers to who
               generated the data in a first instance (ensembl, ucsc...)
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub source {
  my ($self, $arg) = @_;

  if (defined($arg)) {
    $self->{'source'} = $arg ;
  }

  return $self->{'source'};
}


=head2 url

  Arg [1]    : (opt.) string $url
  Example    : my $url = $method_link_species_set->url();
  Example    : $method_link_species_set->url("http://hgdownload.cse.ucsc.edu/goldenPath/monDom1/vsHg17/");
  Description: get/set for attribute url. Defines where the data come from if they
               have been imported. Note that some urls are defined with the prefix '#base_dir#' in the
               database to represent a part that has to be substituted with runtime configuration.
               If a URL contains the #base_dir#' prefix and a return value is wanted, this method returns
               the substituted URL.
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub url {
  my ($self, $arg) = @_;

    if (defined($arg)) {
        # store the original, non-resolved url
        $self->{'original_url'} = $arg ;
        $self->{'url'} = $self->{'original_url'};
    }

    # Attempt to resolve the URL iff a return value is wanted.
    if (defined wantarray()) {  # i.e. if method called in scalar or list context

        if ($self->{'url'} =~ /^#base_dir#/) {
            if (!$self->adaptor) {
                throw(sprintf("Need an adaptor to resolve the location of '%s'", $self->{'url'}));
            }

            my $data_dir = $self->adaptor->base_dir_location;

            $self->{'url'} =~ s/^#base_dir#/$data_dir/;

            if (! -e $self->{'url'}) {
                throw(sprintf("'%s' does not exist on this machine", $self->{'url'}));
            }
        }
    }

  return $self->{'url'};
}


=head2 get_original_url

  Example    : my $url = $method_link_species_set->get_original_url();
  Description: Returns the URL as stored in the database (before substitution)
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub get_original_url {
    my $self = shift;

    return ($self->{'original_url'} || $self->{'url'});
}


=head2 max_alignment_length

  Arg [1]    : (opt.) int $max_alignment_length
  Example    : my $max_alignment_length = $method_link_species_set->
                   max_alignment_length();
  Example    : $method_link_species_set->max_alignment_length(1000);
  Description: get/set for attribute max_alignment_length
  Returntype : integer
  Exceptions : 
  Caller     : general

=cut

sub max_alignment_length {
    my $self = shift @_;
    return $self->_getter_setter_for_tag('max_align', @_) || $DEFAULT_MAX_ALIGNMENT;
}


=head2 toString

  Args       : (none)
  Example    : print $mlss->toString()."\n";
  Description: returns a stringified representation of the method_link_species_set
  Returntype : string

=cut

sub toString {
    my $self = shift;

    my $txt = sprintf('MethodLinkSpeciesSet dbID=%s', $self->dbID || '?');
    $txt .= ' ' . ($self->name ? sprintf('"%s"', $self->name) : '(unnamed)');
    $txt .= sprintf(' {method "%s"} x {species-set "%s"}', $self->method->type, $self->species_set->name || $self->species_set->dbID);
    $txt .= ', located at ' . $self->get_original_url if $self->get_original_url;
    $txt .= ' ' . $self->SUPER::toString();
    return $txt;
}


=head2 species_tree

  Arg[1]      : (optional) String $label (default: "default"). The label of the species-tree to retrieve
  Example     : $mlss->species_tree();
  Description : Returns the species-tree associated to this MLSS
  Returntype  : Bio::EnsEMBL::Compara::SpeciesTree
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub species_tree {
    my ($self, $label) = @_;

    $label ||= 'default';
    my $key = '_species_tree_'.$label;
    return $self->{$key} if $self->{$key};

    my $species_tree = $self->adaptor->db->get_SpeciesTreeAdaptor->fetch_by_method_link_species_set_id_label($self->dbID, $label);

    $self->{$key} = $species_tree;
    return $species_tree;
}

=head2 filename

  Example     : $mlss->filename();
  Description : Returns a nicely formatted directory/file name for this MLSS
  Returntype  : string

=cut

sub filename {
    my $self = shift;

    my $name = $self->species_set->name;
    $name =~ s/collection-//;

    if ( $self->species_set->size > 2 && $self->method->class !~ /tree_node$/ ) {
        $name = $self->species_set->size . "_$name";
    }
    
    # expand species names to include assembly
    if ( $self->species_set->size == 2 ) {
        my ($ref_gdb, $nonref_gdb) = $self->find_pairwise_reference();
        $name = $ref_gdb->get_short_name . "_" . $ref_gdb->assembly . '.v.';
        $name .= $nonref_gdb->get_short_name . "_" . $nonref_gdb->assembly;
    } elsif ( $self->species_set->size == 1 && $self->method->class =~ /pairwise/ ) { # self alignment!
        my $self_aln_gdb = $self->species_set->genome_dbs->[0];
        my $species_label = $self_aln_gdb->get_short_name . "_" . $self_aln_gdb->assembly;
        $name = "$species_label.v.$species_label";
    }

    my $type = $self->method->type;
    my $dir = lc "$name.$type";
    return $dir;
}


=head2 _find_homology_mlss_sets

  Example    : my $mlss_info = $mlss->_find_homology_mlss_sets();
  Description: Internal method to find homology MLSS sets for this gene-tree MLSS.
  Returntype : Hashref containing a breakdown of several categories of MLSS-related info:
               a) 'complementary_gdb_ids': Arrayref of GenomeDB IDs of those genomes in
                  the given MLSS that are not in reference gene-tree MLSSes.
               b) 'complementary_mlss_ids': Arrayref of homology MLSS IDs that are in
                  the given gene-tree MLSS and not in reference gene-tree MLSSes.
               c) 'overlap_gdb_ids': Arrayref of GenomeDB IDs of those genomes in the
                  given MLSS that are also in reference gene-tree MLSSes.
               d) 'overlap_mlss_ids': Arrayref of homology MLSS IDs that are in the
                  given MLSS and also in reference gene-tree MLSSes.
  Exceptions : none

=cut

sub _find_homology_mlss_sets {
    my ($self) = @_;

    unless ($self->is_current && ($self->method->type ne 'PROTEIN_TREES' || $self->method->type ne 'NC_TREES')) {
        throw("MethodLinkSpeciesSet::_find_homology_mlss_sets() can only be used for current gene-tree MLSSes");
    }

    my $mlss_dba = $self->adaptor->db->get_MethodLinkSpeciesSetAdaptor();

    my $ordered_gene_tree_mlsses = $mlss_dba->fetch_current_gene_tree_mlsses();

    my @ref_mlsses;
    foreach my $gene_tree_mlss (@{$ordered_gene_tree_mlsses}) {
        next if $gene_tree_mlss->method->type ne $self->method->type;
        last if $gene_tree_mlss->dbID == $self->dbID;
        push(@ref_mlsses, $gene_tree_mlss);
    }

    my %gdb_id_map;
    my %hom_mlss_id_map;
    foreach my $gene_tree_mlss ($self, @ref_mlsses) {
        my $gene_tree_mlss_id = $gene_tree_mlss->dbID;
        $gdb_id_map{$gene_tree_mlss_id} = [map { $_->dbID } @{$gene_tree_mlss->species_set->genome_dbs}];
        my $hom_mlsses = $mlss_dba->_fetch_gene_tree_homology_mlsses($gene_tree_mlss);
        $hom_mlss_id_map{$gene_tree_mlss_id} = [map { $_->dbID } @{$hom_mlsses}];
    }

    my %agg_ref_gdb_id_set;
    my %agg_ref_hom_mlss_id_set;
    foreach my $ref_mlss (@ref_mlsses) {
        foreach my $hom_mlss_id (@{$hom_mlss_id_map{$ref_mlss->dbID}}) {
            $agg_ref_hom_mlss_id_set{$hom_mlss_id} = 1;
        }
        foreach my $gdb_id (@{$gdb_id_map{$ref_mlss->dbID}}) {
            $agg_ref_gdb_id_set{$gdb_id} = 1;
        }
    }

    my @overlap_gdb_ids;
    my @complementary_gdb_ids;
    foreach my $gdb_id (@{$gdb_id_map{$self->dbID}}) {
        if (exists $agg_ref_gdb_id_set{$gdb_id}) {
            push(@overlap_gdb_ids, $gdb_id);
        } else {
            push(@complementary_gdb_ids, $gdb_id);
        }
    }

    my @overlap_mlss_ids;
    my @complementary_mlss_ids;
    foreach my $hom_mlss_id (@{$hom_mlss_id_map{$self->dbID}}) {
        if (exists $agg_ref_hom_mlss_id_set{$hom_mlss_id}) {
            push(@overlap_mlss_ids, $hom_mlss_id);
        } else {
            push(@complementary_mlss_ids, $hom_mlss_id);
        }
    }

    return {
        'complementary_gdb_ids' => \@complementary_gdb_ids,
        'complementary_mlss_ids' => \@complementary_mlss_ids,
        'overlap_gdb_ids' => \@overlap_gdb_ids,
        'overlap_mlss_ids' => \@overlap_mlss_ids,
    };
}


=head2 find_pairwise_reference

  Example     : my $genome_dbs = $mlss->find_pairwise_reference();
  Description : Returns the genomes involved in this pairwise-alignment MLSS. If
                declared, the reference genome will be in first position. If
                not, the usual reference species will be first. If none of the
                previous conditions apply, the list is sorted alphabetically.
                Note that for self-alignments only one genome is returned.
  Return type : array of Bio::EnsEMBL::Compara::GenomeDB objects
  Exceptions  : none

=cut

sub find_pairwise_reference {
    my $self = shift;

    die "This method can only be used for pairwise-alignment MethodLinkSpeciesSets\n" unless $self->method->class eq 'GenomicAlignBlock.pairwise_alignment';
    die "Cactus alignments are reference-free\n" if $self->method->type eq 'CACTUS_HAL_PW';
    my $genome_dbs = $self->species_set->genome_dbs;

    # For self-alignments, return the single genome
    return @$genome_dbs if (scalar(@$genome_dbs) == 1);

    if ($genome_dbs->[0]->name ne $genome_dbs->[1]->name) {
        # Genome vs genome PWA
        my $ref_name = $self->get_value_for_tag('reference_species', '');
        if ($genome_dbs->[0]->name eq $ref_name) {
            return @$genome_dbs;
        } elsif ($genome_dbs->[1]->name eq $ref_name) {
            return ($genome_dbs->[1], $genome_dbs->[0]);
        } else {
            # In any other case, always place usual references first
            my @ref_list = qw(homo_sapiens mus_musculus gallus_gallus oryzias_latipes arabidopsis_thaliana vitis_vinifera oryza_sativa);
            if ( grep { $genome_dbs->[0]->name eq $_ } @ref_list ) {
                # List already in correct order
                return @$genome_dbs;
            } elsif ( grep { $genome_dbs->[1]->name eq $_ } @ref_list ) {
                return ($genome_dbs->[1], $genome_dbs->[0]);
            } else {
                # Return alphabetical order on name
                @$genome_dbs = sort { $a->name cmp $b->name } @$genome_dbs;
                return @$genome_dbs;
            }
        }
    } else {
        # Same genome: component vs component PWA
        my $ref_component = $self->get_value_for_tag('reference_component', '');
        if ($genome_dbs->[0]->genome_component eq $ref_component) {
            return @$genome_dbs;
        } elsif ($genome_dbs->[1]->genome_component eq $ref_component) {
            return ($genome_dbs->[1], $genome_dbs->[0]);
        } else {
            @$genome_dbs = sort { $a->genome_component cmp $b->genome_component } @$genome_dbs;
            return @$genome_dbs;
        }
    }
}


=head2 _get_gene_tree_member_biotype_groups

  Example    : my $biotype_groups = $mlss->_get_gene_tree_member_biotype_groups();
  Description: Internal method to get biotype groups for members in this gene-tree MLSS.
  Returntype : Listref of biotype groups.
  Exceptions : none

=cut

sub _get_gene_tree_member_biotype_groups {
    my ($self) = @_;

    my $biotype_group_tag = $self->get_value_for_tag('member_biotype_groups');

    my $biotype_groups;
    if (defined $biotype_group_tag) {
        $biotype_groups = [split(/,/, $biotype_group_tag)];
    } else {
        my $sql = q/
            SELECT DISTINCT
                biotype_group
            FROM
                gene_member gm
            JOIN
                gene_tree_node gtn ON gtn.seq_member_id = gm.canonical_member_id
            JOIN
                gene_tree_root gtr ON gtn.root_id = gtr.root_id
            WHERE
                gtr.method_link_species_set_id = ?
            AND
                gtr.ref_root_id IS NULL
        /;
        $biotype_groups = $self->adaptor->dbc->sql_helper->execute_simple( -SQL => $sql, -PARAMS => [$self->dbID] );
    }

    return [sort @{$biotype_groups}];
}


=head2 get_all_sister_mlss_by_class

  Arg[1]      : String $class
  Example     : $mlss->get_all_sister_mlss_by_class('ConstrainedElement.constrained_element');
  Description : Returns the MLSS with the same species-set but a different method
  Returntype  : Arrayref of Bio::EnsEMBL::Compara::MethodLinkSpeciesSet
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub get_all_sister_mlss_by_class {
    my ($self, $class) = @_;
    return unless $self->adaptor;
    my $sql = 'SELECT method_link_species_set_id FROM method_link_species_set JOIN method_link USING (method_link_id) WHERE class = ? AND species_set_id = ?';
    return $self->adaptor->_id_cache->get_by_sql($sql, [$class, $self->species_set->dbID]);
}


=head2 get_linked_mlss_by_tag

  Arg[1]      : String $tag_name
  Example     : $msa_mlss = $cs_mlss->get_linked_mlss_by_tag('msa_mlss_id');
  Description : Returns the MLSS with the dbID given by the value of the tag
  Returntype  : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub get_linked_mlss_by_tag {
    my ($self, $tag_name) = @_;
    return unless $self->adaptor;
    if (my $mlss_id = $self->get_value_for_tag($tag_name)) {
        return $self->adaptor->fetch_by_dbID($mlss_id);
    }
}


=head2 get_all_linked_mlss_by_class_and_reverse_tag

  Arg[1]      : String $class
  Arg[2]      : String $tag_name
  Example     : $ce_mlss = $msa_mlss->get_all_linked_mlss_by_class_and_reverse_tag('ConstrainedElement.constrained_element', 'msa_mlss_id')->[0];
  Description : Returns all the MLSSs of the required class that link back to this MLSS via the tag.
  Returntype  : Arrayref of Bio::EnsEMBL::Compara::MethodLinkSpeciesSet
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub get_all_linked_mlss_by_class_and_reverse_tag {
    my ($self, $class, $tag_name) = @_;
    return unless $self->adaptor;
    my $sql = 'SELECT method_link_species_set_id FROM method_link_species_set_tag JOIN method_link_species_set USING (method_link_species_set_id) JOIN method_link USING (method_link_id) WHERE class = ? AND tag = ? AND value = ?';
    return $self->adaptor->_id_cache->get_by_sql($sql, [$class, $tag_name, $self->dbID]);
}


1;
