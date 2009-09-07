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
  my @results = $object->param('result');

  if (scalar(@results) && $results[0]) {

    my %header = (
      'faq'       =>  'Frequently Asked Questions',
      'glossary'  =>  'Glossary',
      'movie'     =>  'Video Tutorials',
      'view'      =>  'Page Help',
    );

    ## Generate help records first so we can sort them
    my @help_objects;
    foreach my $result (@results) {
      my ($type, $id) = split('_', $result);
      my $help_obj = ucfirst($type);
      my $module = 'EnsEMBL::Web::Data::'.$help_obj;
      if ($self->dynamic_use($module)) {
        my $help_obj = $module->new($id);
        if ($help_obj && $help_obj->status eq 'live') {
          push @help_objects, $help_obj;
        }
      }
    }
   
    my @sorted = sort {$a->type cmp $b->type} @help_objects;

    ## Now display results
    my ($title, $text); 
    my $prev_type = '';
    foreach my $help (@sorted) {
      if ($help->type ne $prev_type) {
        $html .= '<h3>'.$header{$help->type}."</h3>\n";
      }

      if ($help->type eq 'faq') {
        $title  = '<p><strong>'.$help->question.'</strong></p>';
        $text   = $help->answer;
        unless ($text =~ /$</) {
          $text = '<p class="space-below">'.$text.'</p>';
        }
      }
      elsif ($help->type eq 'glossary') {
        $title  = '<p class="space-below"><strong>'.$help->word.'</strong>: ';
        $text   = $help->meaning.'</p>';
      }
      elsif ($help->type eq 'view') {
        $title = '<h4>'.$help->ensembl_object.'/'.$help->ensembl_action.'</h4>';
        $text = $help->content;
        unless ($text =~ /$</) {
          $text = '<p>'.$text.'</p>';
        }
      }
      elsif ($help->type eq 'movie') {
        $title  = '<p class="space-below"><strong><a href="/Help/Movie?id='.$help->id.'" class="popup">'.$help->title.'</a></strong></p>';
        $text   = '';
      }
      if ($object->param('hilite') eq 'yes') {
        $title  = $self->kw_hilite($title);
        $text   = $self->kw_hilite($text);
      }

      $html .= qq($title\n$text); 
      $prev_type = $help->type;
    }
  } 
  else {
    $html = qq(<p>Sorry, no results were found in the help database matching your query.</p>
<ul>
<li><a href="/Help/Search" class="popup">Search again</a></li>
<li><a href="/info/" class="cp-external">Browse non-searchable pages</a></li>
</ul>);
  }

  return $html;
}

1;
