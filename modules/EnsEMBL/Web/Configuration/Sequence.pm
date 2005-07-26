package EnsEMBL::Web::Configuration::Sequence;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Configuration;
our @ISA = qw( EnsEMBL::Web::Configuration );

sub fastaview {
  my $self = shift;
  $self->set_title( $self->{'object'}->fetch_fastaMeta( 'title' ) );

  if( my $panel = $self->new_panel( 'Information',
    'code' => 'fasta#',
    'caption' => $self->{'object'}->fetch_fastaMeta( 'title' )
  )) {
    $panel->add_components(qw(
      id   EnsEMBL::Web::Component::Sequence::id
      desc EnsEMBL::Web::Component::Sequence::meta_description
      lib  EnsEMBL::Web::Component::Sequence::library
      meth EnsEMBL::Web::Component::Sequence::meta_methods
      cred EnsEMBL::Web::Component::Sequence::meta_credits
      link EnsEMBL::Web::Component::Sequence::meta_links
      seq  EnsEMBL::Web::Component::Sequence::sequence
      loc  EnsEMBL::Web::Component::Sequence::genome_locations
      mem  EnsEMBL::Web::Component::Sequence::group_members
    ));
    $self->add_panel( $panel );
  }
}

1;
