package EnsEMBL::Web::Configuration::Alignment;

use strict;
use EnsEMBL::Web::Configuration;

## Function to configure marker view
our @ISA = qw( EnsEMBL::Web::Configuration );

sub alignview {
  my $self   = shift;
  my $class  = $self->{object}->class;
  my $fn  = "alignview_$class";
  if( $self->can( $fn ) ) {
    $self->$fn;
  }
}

sub _formats { return qw(FASTA MSF ClustalW Selex Pfam Mega Nexus Phylip PSI); } 

sub alignview_Family {
  my $self = shift;
  my $object = $self->{object};

  if( my $panel1 = $self->new_panel( '',
    'code'    => "info",
    'caption' => qq(Alignments for Ensembl family @{[CGI::escapeHTML($object->param('family_stable_id'))]}),
  )) {
    $self->add_form( $panel1,
      qw(format EnsEMBL::Web::Component::Alignment::format_form)
    );
    $panel1->add_components(qw(
      format EnsEMBL::Web::Component::Alignment::format
      output EnsEMBL::Web::Component::Alignment::output_Family
    ));
    $self->add_panel( $panel1 );
  }
  $self->add_block( "family", 'bulleted', $object->param('family_stable_id') );
  $self->add_entry(
    "family",
    'text' => 'Family Info',
    'href' => "/@{[$object->species]}/familyview?family=".$object->param('family_stable_id')
  );
  my $HREF = "/@{[$object->species]}/alignview?class=Family;family=".$object->param('family_stable_id');
  $self->add_entry(
    "family",
    'text' => 'Family Alignments',
    'href' => $HREF,
    'options' => [ map { {
      'href' => "$HREF;format=$_",
      'text' => "Export as $_ format"
    }} $self->_formats ]
  );
}

sub alignview_External {
  my $self = shift;
  my $object  = $self->{object};
  my $seqid   = $object->param( 'sequence' );
  my $tranid  = $object->param('transcript');
  my $exonid  = $object->param('exon');
  my $geneid  = $object->param('gene');
  my $title = "Alignment between External Feature: $seqid and";

  $title .= " Gene ID: $geneid" if $geneid;
  $title .= " Exon ID: $exonid" if $exonid;
  $title .= " Transcript ID: $tranid" if $tranid;
    
  if( my $panel1 = $self->new_panel( '', 'code'    => "info", 'caption' => $title) ) {
    $panel1->add_components(qw(
      output EnsEMBL::Web::Component::Alignment::output_External
    ));
    $self->add_panel( $panel1 );
  }
}


sub alignview_Homology {
  my $self = shift;
  my $object = $self->{object};

  my $second_gene = $object->param('g1');
  my $caption = $second_gene ?
    qq(Homology for genes @{[CGI::escapeHTML($object->param('gene'))]} and @{[CGI::escapeHTML($second_gene)]}) :
    qq(Homologies for gene @{[CGI::escapeHTML($object->param('gene'))]});

  if( my $panel1 = $self->new_panel( '',
    'code'    => "info",
    'caption' => $caption
  )) {
    $self->add_form( $panel1,
      qw(format EnsEMBL::Web::Component::Alignment::format_form)
    );
    $panel1->add_components(qw(
      format EnsEMBL::Web::Component::Alignment::format
      output EnsEMBL::Web::Component::Alignment::output_Homology
    ));
    $self->add_panel( $panel1 );
  }
}


sub alignview_GeneTree {
  my $self = shift;
  my $object = $self->{object};

  my $caption =  qq(GeneTree for gene @{[CGI::escapeHTML($object->param('gene'))]});

  if( my $panel1 = $self->new_panel( '',
    'code'    => "info",
    'caption' => $caption
  )) {
    $self->add_form( $panel1,
      qw(format EnsEMBL::Web::Component::Alignment::format_form)
    );
    $panel1->add_components(qw(
      format EnsEMBL::Web::Component::Alignment::format
      output EnsEMBL::Web::Component::Alignment::output_GeneTree
    ));
    $self->add_panel( $panel1 );
  }
}


sub alignview_AlignSlice {
    my $self = shift;
    my $object = $self->{object};

    my $caption = sprintf("Alignment of Genomic location %s:%s:%ld-%ld", 
			  $ENV{ENSEMBL_SPECIES}, 
			  $object->param('chr'),
			  $object->param('bp_start'),
			  $object->param('bp_end'));

    if( my $panel1 = $self->new_panel( '',
				       'code'    => "info",
				       'caption' => $caption
				       )) {


	$self->add_form( $panel1,
			 qw(format EnsEMBL::Web::Component::Alignment::format_form)
			 );
	$panel1->add_components(qw(
				   format EnsEMBL::Web::Component::Alignment::format
				   output EnsEMBL::Web::Component::Alignment::output_AlignSlice
				   ));
	$self->add_panel( $panel1 );
    }


}

sub alignview_DnaDnaAlignFeature {
  my $self = shift;
  my $object = $self->{object};

  if( my $panel1 = $self->new_panel( '',
    'code'    => "info",
    'caption' => qq(Dna-Dna alignment)
  )) {
    $panel1->add_components(qw(
      output EnsEMBL::Web::Component::Alignment::output_DnaDnaAlignFeature
    ));
    $self->add_panel( $panel1 );
  }
  my $align = $object->Obj->[0];
  my $context = 20e3;
  if( $align ) {
    my $sr = $align->seqname;
    my $cs = $align->slice->coord_system_name;
    my $rexp = "^$cs";
    (my $species = $align->species ) =~ s/ /_/g;
    my $label = sprintf "<em>%s</em> %s: %s - %s", $align->species,
      ( $sr =~ /$rexp/ ? $sr : ucfirst("$cs $sr") ), $object->thousandify( $align->start), $object->thousandify( $align->end );
    my $url   = sprintf "/%s/contigview?l=%s:%s-%s", $species, $sr, $align->start - $context, $align->end + $context;
    $self->add_block( 'primary', 'bulleted', $label, 'raw'=>1 );
    $self->add_entry( 'primary', 'text' => 'Graphical view', 'href' => $url );
    $url =~s/contigview/cytoview/g;
    $self->add_entry( 'primary', 'text' => 'Graphical overview', 'href' => $url );
    
    $sr =  $align->hseqname;
    $cs = $align->hslice->coord_system_name;
    (my $hspecies = $align->hspecies ) =~ s/ /_/g;
    $rexp = "^$cs";
    $label = sprintf "<em>%s</em> %s: %s - %s", $align->hspecies,
      ( $sr =~ /$rexp/ ? $sr : ucfirst("$cs $sr") ), $object->thousandify( $align->hstart), $object->thousandify( $align->hend );
    $url   = sprintf "/%s/contigview?l=%s:%s-%s", $hspecies, $sr, $align->hstart - $context, $align->hend + $context;
    $self->add_block( 'secondary', 'bulleted', $label,'raw'=>1 );
    $self->add_entry( 'secondary', 'text' => 'Graphical view', 'href' => $url );
    $url =~s/contigview/cytoview/g;
    $self->add_entry( 'secondary', 'text' => 'Graphical overview', 'href' => $url );
  }
}

1;
