package EnsEMBL::Web::Component::Alignment;

# outputs chunks of XHTML for protein domain-based displays

use EnsEMBL::Web::Component;
our @ISA = qw(EnsEMBL::Web::Component);
use Bio::AlignIO;
use IO::String;

use strict;
use warnings;
no warnings "uninitialized";

sub SIMPLEALIGN_FORMATS { return {
  'fasta'    => 'FASTA',
  'msf'      => 'MSF',
  'clustalw' => 'CLUSTAL',
  'selex'    => 'Selex',
  'pfam'     => 'Pfam',
  'mega'     => 'Mega',
  'nexus'    => 'Nexus',
  'phylip'   => 'Phylip',
  'psi'      => 'PSI',
}; }

sub HOMOLOGY_TYPES {
  return {
    'BRH'  => 'Best Reciprocal Hit',
    'UBRH' => 'Unique Best Reciprocal Hit',
    'RHS'  => 'Reciprocal Hit based on Synteny around BRH',
    'DWGA' => 'Derived from Whole Genome Alignment'
  };
}

sub param_list {
  my $class = shift;
  my $T = {
    'Family'   => [qw(family_stable_id)],
    'Homology' => [qw(gene g1)],
    'GeneTree' => [qw(gene)],
    'AlignSlice' => [qw(chr bp_start bp_end as method s)],
  };
  return @{$T->{$class}||[]};
}
sub SIMPLEALIGN_DEFAULT { return 'clustalw'; }

sub format_form {
  my( $panel, $object ) = @_;
  my $class = $object->param('class');
  my $form = EnsEMBL::Web::Form->new( 'format_form', "/@{[$object->species]}/alignview", 'get' );
  foreach my $K ( 'class', param_list( $class ) ) {
    $form->add_element( 'type' => 'Hidden', 'name' => $K, 'value' => $object->param($K) );
  }
  if( $class eq 'Homology' ) {
    $form->add_element(
      'type' => 'DropDown', 
      'select' => 'select',
      'name' => 'seq',
      'label' => 'Display sequence as',
      'value' => $object->param('seq')||'Pep',
      'values' => [
        { 'value'=>'Pep', 'name' => 'Peptide' },
        { 'value'=>'DNA', 'name' => 'DNA' },
      ]
    );
  }
  my $hash = SIMPLEALIGN_FORMATS;
  $form->add_element( 
    'type' => 'DropDownAndSubmit', 
    'select' => 'select',
    'name' => 'format',
    'label' => 'Change output format to:',
    'value' => $object->param('format')||SIMPLEALIGN_DEFAULT,
    'button_value' => 'Go',
    'values' => [
      map {{ 'value' => $_, 'name' => $hash->{$_} }} sort keys %$hash
    ]
  );
  return $form;
}

sub format {
  my( $panel, $object ) = @_;
  $panel->print( $panel->form('format')->render );
  return 1;
}

sub renderer_type {
  my $K = shift;
  my $T = SIMPLEALIGN_FORMATS;
  return $T->{$K} ? $K : SIMPLEALIGN_DEFAULT;
}

sub output_Family {
  my( $panel, $object ) = @_;
  foreach my $family (@{$object->Obj||[]}) {
    my $alignio = Bio::AlignIO->newFh(
      -fh     => IO::String->new(my $var),
      -format => renderer_type($object->param('format'))
    );
    print $alignio $family->get_SimpleAlign();
    $panel->print("<pre>$var</pre>\n");
  }
}

sub output_Homology {
  my( $panel, $object ) = @_;

  my %desc_mapping= ('ortholog_one2one' => '1 to 1 orthologue', 'apparent_ortholog_one2one' => '1 to 1 orthologue (apparent)', 'ortholog_one2many' => '1 to many orthologue', 'between_species_paralog' => 'paralogue (between species)', 'ortholog_many2many' => 'many to many orthologue', 'within_species_paralog' => 'paralogue (within species)');
  
  foreach my $homology (@{$object->Obj||[]}) {
    my $sa;
    eval { $sa = $homology->get_SimpleAlign( $object->param('seq') eq 'DNA' ? 'cdna' : undef ); };
    my $second_gene = $object->param('g1');
    if( $sa ) {
      my $DATA = [];
      my $FLAG = ! $second_gene;
      foreach my $member_attribute (@{$homology->get_all_Member_Attribute}) {
        my ($member, $attribute) = @{$member_attribute};
        $FLAG = 1 if $member->stable_id eq $second_gene;
        my $peptide = $member->{'_adaptor'}->db->get_MemberAdaptor()->fetch_by_dbID( $attribute->peptide_member_id );
        my $species = $member->genome_db->name;
        (my $species2 = $species ) =~s/ /_/g;
        push @$DATA, [
          $species,
          sprintf( '<a href="/%s/geneview?gene=%s">%s</a>' , $species2, $member->stable_id,$member->stable_id ),
          sprintf( '<a href="/%s/protview?peptide=%s">%s</a>' , $species2, $peptide->stable_id,$peptide->stable_id ),
          sprintf( '%d aa', $peptide->seq_length ),
          sprintf( '<a href="/%s/contigview?l=%s:%d-%d">%s:%d-%d</a>',$species2,
          $member->chr_name, $member->chr_start, $member->chr_end,
          $member->chr_name, $member->chr_start, $member->chr_end )
        ];
      }
      next unless $FLAG;
      my $homology_types = HOMOLOGY_TYPES;

      my $homology_desc= $homology_types->{$homology->{_description}} || $homology->{_description};

      # filter out the between species paralogs
      next if($homology_desc eq 'between_species_paralog');
      
      my $homology_desc_mapped= $desc_mapping{$homology_desc};
      $homology_desc_mapped= 'no description' unless (defined $homology_desc_mapped);
      
      $panel->print( sprintf( '<h3>"%s" homology for gene %s</h3>',
      $homology_desc_mapped,
      $homology->{'_this_one_first'} ) );
      my $ss = EnsEMBL::Web::Document::SpreadSheet->new(
        [ { 'title' => 'Species', 'width'=>'20%' },
          { 'title' => 'Gene ID', 'width'=>'20%' },
          { 'title' => 'Peptide ID', 'width'=>'20%' },
          { 'title' => 'Peptide length', 'width'=>'20%' },
          { 'title' => 'Genomic location', 'width'=>'20%' } ],
        $DATA
      );
      $panel->print( $ss->render );
      my $alignio = Bio::AlignIO->newFh(
        -fh     => IO::String->new(my $var),
        -format => renderer_type($object->param('format'))
      );
      print $alignio $sa;
      $panel->print("<pre>$var</pre>\n");
    }
  }
}

sub output_AlignSlice {
    my( $panel, $object ) = @_;

    my $as = $object->Obj;
    (my $esp = $ENV{ENSEMBL_SPECIES}) =~ s!_! !g;
    

    my @species;

    if ($object->param('s')) {
	foreach my $sp  (split(/,/, $object->param('s'))) {
	    $sp =~ s!_! !g;
	    push @species, $sp unless ( $sp eq $esp);
	}

    } else {
	my $ss = $as->get_MethodLinkSpeciesSet->species_set;
	foreach my $gdb (@$ss) {
	    push @species, $gdb->name unless ( $gdb->name eq $esp);
	}
    }

    my $sa = $as->get_SimpleAlign($esp, @species);
    
    my $type = $as->get_MethodLinkSpeciesSet->method_link_type;
    my $name = $as->get_MethodLinkSpeciesSet->name;

    
    my $info = qq{
<table>
  <tr>
    <td> Secondary species: </td>
    <td> %s </td>
  </tr>
  <tr>
    <td> Method: </td>
    <td> %s </td>
  </tr>
  <tr>
    <td> Species set: </td>
    <td> %s </td>
  </tr>

</table>
    };

    $panel->print(sprintf($info, join(", ", @species), $type, $name));

    my $alignio = Bio::AlignIO->newFh(
				      -fh     => IO::String->new(my $var),
				      -format => renderer_type($object->param('format'))
			
				     );

    print $alignio $sa;
    $panel->print("<pre>$var</pre>\n");
    return ;
}

use EnsEMBL::Web::Document::SpreadSheet;
sub output_DnaDnaAlignFeature {
  my( $panel, $object ) = @_;
  foreach my $align ( @{$object->Obj||[]} ) {
    $panel->printf( qq(<h3>%s alignment between %s %s %s and %s %s %s</h3>),
      $align->{'alignment_type'}, $align->species,  $align->slice->coord_system_name, $align->seqname,
                                $align->hspecies, $align->hslice->coord_system_name, $align->hseqname
    );

    my $BLOCKSIZE = 60;
    my $REG       = "(.{1,$BLOCKSIZE})";
    my ( $ori, $start, $end ) = $align->strand < 0 ? ( -1, $align->end, $align->start ) : ( 1, $align->start, $align->end );
    my ( $hori, $hstart, $hend ) = $align->hstrand < 0 ? ( -1, $align->hend, $align->hstart ) : ( 1, $align->hstart, $align->hend );
    my ( $seq,$hseq) = @{$align->alignment_strings()||[]};
    $panel->print( "<pre>" );
    while( $seq ) {
      $seq  =~s/$REG//; my $part = $1;
      $hseq =~s/$REG//; my $hpart = $1;
      $panel->print( sprintf( "%9d %-60.60s %9d\n%9s ", $start, $part, $start + $ori * ( length( $part) - 1 ),' ' ) );
      my @BP = split //, $part;
      foreach( split //, ($part ^ $hpart ) ) {
        $panel->print( ord($_) ? ' ' : $BP[0] );
        shift @BP;
      }
      $panel->print( sprintf( "\n%9d %-60.60s %9d\n\n", $hstart, $hpart, $hstart + $hori * ( length( $hpart) - 1 ) ) );
      $start += $ori * $BLOCKSIZE;
      $hstart += $hori * $BLOCKSIZE;
    }
    $panel->print( "</pre>" );
  }
}

sub output_External {
  my( $panel, $object ) = @_;
  foreach my $align ( @{$object->Obj||[]} ) {
    $panel->print(
      "<pre>",
        map( { $_->{'alignment'} } @{ $align->{'internal_seqs'} } ),
      "</pre>"
    );
  }
  return 1;
}


=head2 output_External_trans_al

 Arg[1]	     : information panel (EnsEMBL::Web::Document::Panel::Information)
 Arg[2]	     : object (EnsEMBL::Web::Proxy::Object)
 Example     : $panel->add_components(qw(trans_alignment  EnsEMBL::Web::Component::Alignment::output_External_trans_al)
 Description : Formats pairwise alignment of transcript and external record

=cut

sub output_External_trans_al {
  my( $panel, $object ) = @_;
  my $html;
  my $label = 'Transcript alignment';
  my $al = $panel->{'params'}{'trans_alignment'}; 
  $html = "<pre>$al</pre>";
  $panel->add_row( $label, $html );
  return 1;
}


=head2 output_External_exon_al

 Arg[1]	     : information panel (EnsEMBL::Web::Document::Panel::Information)
 Arg[2]	     : object (EnsEMBL::Web::Proxy::Object)
 Example     : $panel->add_components(qw(exon_alignment  EnsEMBL::Web::Component::Alignment::output_External_exon_al)
 Description : Formats pairwise alignment of exon and external alignment

=cut

sub output_External_exon_al {
  my( $panel, $object ) = @_;
  my $html;
  my $label = 'Exon alignment';
  my $al = $panel->{'params'}{'exon_alignment'};
  $html = "<pre>$al</pre>";
  $panel->add_row( $label, $html );
  return 1;
}


=head2 output_External_exon_al

 Arg[1]	     : information panel (EnsEMBL::Web::Document::Panel::Information)
 Arg[2]	     : object (EnsEMBL::Web::Proxy::Object)
 Example     : $panel->add_components(qw(external_info  EnsEMBL::Web::Component::Alignment::external_information)
 Description : Formats link to an external record

=cut

sub external_information {
  my( $panel, $object ) = @_;
  my $html;	
  my $label = 'External record';
  my $id = $panel->{'params'}{'external_id'};
  my $link;
  my $evidence = $object->get_supporting_evidence;
  foreach my $hit (keys %{$evidence->{'hits'}}) {
	  if ($hit eq $id) {
		  $link = $evidence->{'hits'}->{$hit}->{'link'};
	  }
  }
  $html = "<p><a href=$link>$id</a></p>";
  $panel->add_row( $label, $html );
  return 1;
}


=head2 exon_infomration

 Arg[1]	     : information panel (EnsEMBL::Web::Document::Panel::Information)
 Arg[2]	     : object (EnsEMBL::Web::Proxy::Object)
 Example     : $panel->add_components(qw(exon_info  EnsEMBL::Web::Component::Alignment::exon_information)
 Description : Formats display of exon cDNA coordinates

=cut

sub exon_information {
  my( $panel, $object ) = @_;
  my $label = 'Exon information';
  my $exon_id = $panel->{'params'}{'exon_id'};
  my $trans = $object->Obj;
  my $db = $object->get_db || 'core';
  my $exon = $object->get_exon($exon_id,$db);
  my $trmapper = Bio::EnsEMBL::TranscriptMapper->new($trans);
  my @cdna_coords = $trmapper->genomic2cdna($exon->start, $exon->end, $exon->strand);
  my ($cdna_start,$cdna_end);
  foreach my $map (@cdna_coords) {
	  $cdna_start = $map->start;
	  $cdna_end   = $map->end;
  }
  my $html = "<p><strong>$exon_id</strong></p>";
  $html .= "transcript start = ${cdna_start}bp, transcript end = ${cdna_end}bp";
  $panel->add_row( $label, $html );
  return 1;
}

sub output_GeneTree {
  my( $panel, $object ) = @_;
  my $tree = $object->Obj;
  my $alignio = Bio::AlignIO->newFh(
				    -fh     => IO::String->new(my $var),
				    -format => renderer_type($object->param('format'))
				    );
      
  print $alignio $tree->get_SimpleAlign();
  $panel->print("<pre>$var</pre>\n");
}

1;
