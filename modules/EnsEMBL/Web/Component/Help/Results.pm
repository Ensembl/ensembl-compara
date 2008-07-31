package EnsEMBL::Web::Component::Help::Results;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Help);
use CGI qw(escapeHTML);
use EnsEMBL::Web::Data::Faq;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $html = qq(<h2>Search Results</h2>);

  my %header = (
    'faq'       =>      'Frequently Asked Questions',
    'glossary'  =>      'Glossary',
    'movie'     =>      'Tutorials',
  );

  ## Generate help records first so we can sort them
  my @results = $object->param('result');
  my @help_objects;
  if (@results) {
    foreach my $result (@results) {
      my ($type, $id) = split('_', $result);
      my $help_obj = ucfirst($type);
      my $module = 'EnsEMBL::Web::Data::'.$help_obj;
      if ($self->dynamic_use($module)) {
        push @help_objects, $module->new($id);
      }
    }
  }
  my @sorted = sort {$a->type cmp $b->type} @help_objects;

  ## Now display results
  my ($text, $prev_type);
  foreach my $help (@sorted) {
    if ($help->type ne $prev_type) {
      $html .= "</ul>\n" if $prev_type;
      $html .= '<h3>'.$header{$help->type}."</h3>\n<ul>\n";
    }
    if ($help->type eq 'faq') {
      $text = $help->question;
    }
    elsif ($help->type eq 'glossary') {
      $text = $help->word.': '.substr($help->meaning, 0, 50);
    }
    else {
      $text = $help->title;
    }
    $html .= sprintf(qq(<li><a href="/Help/%s?id=%s;type=%s">%s</a></li>), 
                          ucfirst($help->type), $help->id, $help->type, $text);
    $prev_type = $help->type;
  }
  $html .= "</ul>\n";

  return $html;
}

1;
