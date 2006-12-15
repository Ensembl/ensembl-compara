package EnsEMBL::Web::Document::DropDown::Menu::AlignCompara;


=head1 NAME

EnsEMBL::Web::Document::DropDown::Menu::AlignCompara

=head1 SYNOPSIS

The object handles the 'Comparative' dropdown menu in alignsliceview 

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Eugene Kulesha - ek3@sanger.ac.uk

=cut

use strict;
use EnsEMBL::Web::Document::DropDown::Menu;

our @ISA =qw( EnsEMBL::Web::Document::DropDown::Menu );

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(
    @_, ## This contains the menu containers as the first element
    'image_name'  => 'y-compara',
    'image_width' => 88,
    'alt'         => 'Multiple Alignments'
  );
  
  my $species = $ENV{ENSEMBL_SPECIES};

  my %alignments = $self->{'config'}->species_defs->multiX('ALIGNMENTS');

  my @multiple_alignments;
  my @pairwise_alignments;

  foreach my $id (
		  sort { 10 * ($alignments{$a}->{'type'} cmp $alignments{$b}->{'type'}) + ($a <=> $b) }
		  grep { $alignments{$_}->{'species'}->{$species} } 
		  keys (%alignments)) {

      my $sp = $alignments{$id}->{'name'};
      my $constr_elem = $alignments{$id}->{'constrained_element'};
      my $conserv_score = $alignments{$id}->{'conservation_score'};

      my @species = grep {$_ ne $species} sort keys %{$alignments{$id}->{'species'}};

      if ( scalar(@species) > 1) {
	  push @multiple_alignments, [ $id, $sp, $constr_elem, $conserv_score, @species ];
      } else {
	  push @pairwise_alignments, [ $id, $species[0] ];
      }
  }

  if (@multiple_alignments) {
      $self->add_text("Multiple Alignments");
  }

  foreach my $align (@multiple_alignments) {
      my ($id, $label, $constr_elem, $conserv_score, @sspecies) = @$align;
      $self->add_radiobutton( "opt_align_$id", $label );
      foreach my $sp (sort @sspecies ) { 
	  $self->add_checkbox( "opt_${id}_$sp", $sp );
      }
      if ($constr_elem or $conserv_score) {
        $self->add_text(" ");
        if ($conserv_score) {
          $self->add_checkbox( "opt_${id}_conservation_score", "Display conservation scores" );
        }
        if ($constr_elem) {
          $self->add_checkbox( "opt_${id}_constrained_elem", "Display constrained elements" );
        }
      }
      $self->add_text(" ");
  }

  if (@pairwise_alignments) {
      $self->add_text("Pairwise Alignments");  
  }
  foreach my $align (@pairwise_alignments) {
      my ($id, $label) = @$align;
      $self->add_radiobutton( "opt_align_$id", $label );
  }
  return $self;
}

1;
