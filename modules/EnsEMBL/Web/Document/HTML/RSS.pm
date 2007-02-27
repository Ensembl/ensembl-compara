package EnsEMBL::Web::Document::HTML::RSS;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;

@EnsEMBL::Web::Document::HTML::RSS::ISA = qw(EnsEMBL::Web::Document::HTML);

sub new      {
  return shift->SUPER::new( 'feeds' => {} );
}

sub add      { 
  my( $self, $URL, $title, $type ) = @_;
  $self->{'feeds'}{$URL} = { 'title' => $title, 'type' => $type };
}

sub render   {
  my $self = shift;
  $self->printf(qq(<link rel="search" href="http://dev.ensembl.org/opensearchdescription.xml" type="application/opensearchdescription+xml" title="Ensembl" />\n));
  foreach (keys %{$self->{'feeds'}}) {
    $self->printf(
      qq(<link rel="alternate" type="application/%s+xml" title="%s" href="%s" />),
      $self->{'feeds'}{$_}{'type'},
      CGI::escapeHTML($self->{'feeds'}{$_}{'title'}),
      $_ 
    );
  }
}

1;

