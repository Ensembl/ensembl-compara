package EnsEMBL::Web::Factory::Alignment;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::ExtIndex;

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::Document::SpreadSheet;
our @ISA = qw(  EnsEMBL::Web::Factory );

=head2 _createObjects

 Arg[1]      : none
 Example     : $self->_createObjects()
 Description : Always called from the parent module, 
               Creates and checks ensembl object(s)
 Return type : Nothing

=cut

sub _createObjects {
  my( $self, $objects, $class ) = @_;
  my $obj  = EnsEMBL::Web::Proxy::Object->new( 'Alignment', $objects, $self->__data );

  $obj->class( $class );
  $self->DataObjects( $obj );
}


sub _prob {
  my( $self, $caption, $error ) = @_;
  $self->problem( 'fatal', $caption, $self->web_usage.$error );
}


sub web_usage {
  my $self = shift;
  my $ss = EnsEMBL::Web::Document::SpreadSheet->new(
    [ { 'title' => 'Class' }, {'title' => 'Description'}, { 'title' => 'Required' },
      { 'title' => 'Optional' } ],
    []
  );
  foreach my $method (sort keys %EnsEMBL::Web::Factory::Alignment::) {
    next unless $method =~ /(usage_(\w+))$/;
    my $class = $2;
    my( $desc, $req, $opt ) = $self->$1();
    $ss->add_row([ $class, $desc,
      @$req ? qq(<dl><dt>@{[join ";</dt>\n<dt>", map {qq(<strong>$_->[0]</strong>: $_->[1])} @$req  ]}.</dt></dl>) : '&nbsp;',
      @$opt ? qq(<dl><dt>@{[join ";</dt>\n<dt>", map {qq(<strong>$_->[0]</strong>: $_->[1])} @$opt  ]}.</dt></dl>) : '&nbsp;'
    ]);
  }
  return '
  <p>
    The following classes of alignment can be rendered.
    A list of required and optional parameters are 
    listed:</p>'.
  $ss->render;
}

sub createObjects {
  my $self                 = shift;
  my $class                = $self->param('class');

  unless( $class ) {
    $class = 'External' if $self->param('sequence');
    $class = 'Supporting' if $self->param('sequence') && ($self->param('exon') || $self->param('trans'));
    $class = 'Family'   if $self->param('family_stable_id');
  }
  if( $class ) {
    my $method = "createObjects_$class";
    if( $self->can( $method ) ) {
      $self->$method;
    } else {
      $self->_prob( 'Unknown alignment class' );
    }
  } else {
    $self->_prob( 'Unspecified alignment class' );
  }
}

#---------

sub usage_AlignSlice {
  return 
    'AlignSlice Comparative',
    [ ['chr' => 'Name of the region' ]],
    [ ['bp_start' => 'Start of AlignSlice' ]],
    [ ['bp_end' => 'End of AlignSlice' ]],
    [ ['region' => 'Type of the region (scaffold etc, default - chromosome)']],
    [ ['method' => 'Compara method to get AlignSlice' ]],
    [ ['s'   => 'Secondary species'],
      ['format' => 'SimpleAlign renderer name'] ]
}

sub createObjects_AlignSlice {
  my $self            = shift;
  my $databases       = $self->DBConnection->get_databases( 'core', 'compara' ); #, 'compara_multiple' );

  my ($seq_region_name, $start, $end) = ($self->param('chr'), $self->param('bp_start'), $self->param('bp_end'));

  
  my $species = $ENV{ENSEMBL_SPECIES};
  my $query_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, "core", "Slice");

  my $cs = $self->param('region') || 'chromosome';

  my $query_slice= $query_slice_adaptor->fetch_by_region($cs, $seq_region_name, $start, $end);


  my $id = $self->param('method') or return $self->_prob( 'Alignment ID is not provided');

  my $comparadb = $databases->{'compara'};
  
  my $mlss_adaptor = $comparadb->get_adaptor("MethodLinkSpeciesSet");

  my $method_link_species_set = $mlss_adaptor->fetch_by_dbID($id);

  return $self->_prob( "Unable to get Method Link Species Set $id" ) unless $method_link_species_set;
  eval {
      my $asa = $comparadb->get_adaptor("AlignSlice" );
      my $align_slice = $asa->fetch_by_Slice_MethodLinkSpeciesSet($query_slice, $method_link_species_set, "expanded", "restrict" );

      $self->_createObjects( $align_slice, 'AlignSlice' );
  };


  return $self->_prob( 'Unable to get AlignSlice', "<pre>$@</pre>" ) if $@;
}

sub usage_Homology {
  return 
    'Comparative gene homologies',
    [ ['gene' => 'Name of gene' ]],
    [ ['g1'   => 'Secondary gene'],
      ['format' => 'SimpleAlign renderer name'] ]
}

sub usage_Family {
  return 
    'Comparative family alignments',
    [ ['family_stable_id' => 'Ensembl family identifier'] ],
    [ ['format'           => 'SimpleAlign renderer name'] ];
}

sub createObjects_Family {
  my $self        = shift;
  my $databases   = $self->DBConnection->get_databases( 'core', 'compara' );
  my $compara_db  = $databases->{'compara'};
  my $family;
  eval { $family = $compara_db->get_FamilyAdaptor()->fetch_by_stable_id( $self->param( 'family_stable_id' ) ); };
  return $self->_prob( "unable to create Protein family" ) if $@ || !defined $family;
  $self->_createObjects( [$family], 'Family' );
}

sub usage_DnaDnaAlignFeature {
  return
    'Comparative DNA-DNA alignment',
    [ ['l = location in primary species'],
      ['s1 = secondary species'],
      ['l1 = location in secondary species'],
      ['type = type of match (TBLAT, BLASTZ...)'] ], 
    [];
}

sub createObjects_DnaDnaAlignFeature {
  my $self                       = shift;
  my $databases                  = $self->DBConnection->get_databases( 'core', 'compara' );
  (my $p_species                 = $self->species ) =~ s/_/ /;
  (my $s_species                 = $self->param('s1')      ) =~ s/_/ /;
  my( $p_chr, $p_start, $p_end ) = $self->param('l')=~/^(.+):(\d+)-(\d+)$/;
  my( $s_chr, $s_start, $s_end ) = $self->param('l1')=~/^(.+):(\d+)-(\d+)$/;
  my $type                       = $self->param( 'type' );
  my $compara_db                 = $databases->{'compara'};
  my $dafa                       = $compara_db->get_DnaAlignFeatureAdaptor;
  my $features;
  eval {
    $features = $dafa->fetch_all_by_species_region(
      $p_species, undef, $s_species, undef, $p_chr, $p_start, $p_end, $type
    );
  };
warn $@;
  return $self->_prob( 'Unable to find Dna Dna alignment' ) if $@;
  my $objects                    = [];
  foreach my $f ( @$features ) {
warn $f->seqname;
    if( $f->seqname eq $p_chr && $f->start == $p_start && $f->end == $p_end && $f->hseqname eq $s_chr && $f->hstart == $s_start && $f->hend == $s_end ) {
      push @$objects, $f; ## This IS the aligmnent of which we speak 
    }
  }
  return $self->_prob( 'Unable to find Dna Dna alignment' ) unless @$objects;
  $self->_createObjects( $objects, 'DnaDnaAlignFeature' ); 
}

sub usage_External {
  return
    'Alignment with external sequence',
    [ ['sequence', 'Identifier of external sequence'],
      ['ext_db',   'source of external sequence'],
      ['gene/transcript/exon', 'Identifier of internal sequence'] ],
    [];
}

sub usage_GeneTree {
  return 
    'Comparative gene homologies',
    [ ['gene' => 'Name of gene' ]],
    [ ['format' => 'SimpleAlign renderer name'] ]
}

sub createObjects_GeneTree {
  my $self            = shift;
  my $databases       = $self->DBConnection->get_databases( 'core', 'compara' );
  my $compara_db      = $databases->{'compara'};
  my $ma              = $compara_db->get_MemberAdaptor;
  my $member          = $ma->fetch_by_source_stable_id("ENSEMBLGENE",$self->param('gene'));
  return $self->_prob( 'Unable to find gene' ) unless $member;
  eval {
      my $clusterset_id = 0; 
      my $treeDBA = $compara_db->get_ProteinTreeAdaptor;
      my $aligned_member = $treeDBA->fetch_AlignedMember_by_member_id_root_id(
									      $member->get_longest_peptide_Member->member_id,
									      $clusterset_id);

      my $node = $aligned_member->subroot;
      my $tree = $treeDBA->fetch_node_by_node_id($node->node_id);
      $node->release_tree;
      $self->_createObjects( $tree, 'GeneTree' );
  };
  return $self->_prob( 'Unable to get homologies', "<pre>$@</pre>" ) if $@;
}

1;

