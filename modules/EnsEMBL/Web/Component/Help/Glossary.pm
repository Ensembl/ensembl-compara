package EnsEMBL::Web::Component::Help::Glossary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Help);
use CGI qw(escapeHTML);
use EnsEMBL::Web::Data::Glossary;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $html = qq(<h2>Glossary</h2>);

  my @words;
  if ($object && $object->param('id')) {
    my @ids = $object->param('id');
    foreach my $id (@ids) {
      push @words, EnsEMBL::Web::Data::Glossary->new($id);
    }
  }
  else {
    @words = sort {lc($a->word) cmp lc($b->word)} EnsEMBL::Web::Data::Glossary->find_all;
  }

  if (scalar(@words)) {
  
    my $style = 'text-align:right;margin-right:2em';
    $html .= qq(<dl class="normal">\n); 

    foreach my $word (@words) {
      next unless $word->status eq 'live';

      $html .= sprintf(qq(<dt id="word%s">%s), $word->help_record_id, $word->word);
      if ($word->expanded) {
        $html .= ' ('.$word->expanded.')';
      }
      $html .= "</dt>\n<dd>".$word->meaning."</dd>\n";
    }
    $html .= "</dl>\n";
  }

  return $html;
}

1;
