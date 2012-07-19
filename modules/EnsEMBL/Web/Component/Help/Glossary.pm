package EnsEMBL::Web::Component::Help::Glossary;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Hub;
use EnsEMBL::Web::DBSQL::WebsiteAdaptor;

use base qw(EnsEMBL::Web::Component::Help);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $hub = $self->hub || new EnsEMBL::Web::Hub;

  my $adaptor = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub);


  my $html = qq(<h2>Glossary</h2>);

  my @words;
  if ($hub->param('id')) {
    my @ids = $hub->param('id');
    @words = @{$adaptor->fetch_help_by_ids(\@ids)};
  }
  else {
    @words = @{$adaptor->fetch_glossary};
  }

  if (scalar(@words)) {
  
    $html .= qq(<dl class="normal striped twocol">\n); 

    my @bg = qw(bg1 bg2);

    foreach my $word (@words) {
      $html .= qq(<dt id="word$word->{'id'}" class="$bg[1]">$word->{'word'});
      if ($word->{'expanded'}) {
        $html .= " ($word->{'expanded'})";
      }
      $html .= qq(</dt>\n<dd class="$bg[1]">$word->{'meaning'}</dd>\n);
      @bg = reverse @bg;
    }
    $html .= "</dl>\n";
  }

  return $html;
}

1;
