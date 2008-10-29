package EnsEMBL::Web::Component::Account::NewsFilters;

### Module to create user news filter list

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Account);
use EnsEMBL::Web::Form;
use EnsEMBL::Web::RegObj;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return undef;
}

sub content {
  my $self = shift;
  my $html;

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $sitename = $self->site_name;

  my @filters = $user->newsfilters;
  my $has_filters = 0;

  if ($#filters > -1) {

    $html .= qq(<h3>Your news filters</h3>);
    ## Sort user filters by name if required

    ## Display user filters
    my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );

    $table->add_columns(
        { 'key' => 'species',   'title' => 'Species',       'width' => '60%', 'align' => 'left' },
        { 'key' => 'edit',      'title' => '',              'width' => '20%', 'align' => 'left' },
        { 'key' => 'delete',    'title' => '',              'width' => '20%', 'align' => 'left' },
    );

    foreach my $filter (@filters) {
      my $row = {};
      my $species = join(', ', @{$filter->species});

      $row->{'species'} = sprintf(qq(<a href="/News" title="View News" class="cp-external">%s</a>),
                        $species);

      $row->{'edit'} = $self->rename_link('NewsFilter', $filter->id);
      $row->{'delete'} = $self->delete_link('NewsFilter', $filter->id);
      $table->add_row($row);
      $has_filters = 1;
    }
    $html .= $table->render;
  }


  if (!$has_filters) {
    $html .= qq(<p class="center"><img src="/img/help/filter_example.gif" alt="Sample screenshot" title="SAMPLE" /></p>);
    $html .= qq(<p class="center">You do not have any filters set, so you will see general headlines.</p>
<p><a href="/Account/News?_referer=).CGI::escape($self->object->param('_referer')).'" class="modal_link">Add a news filter &rarr;</a></p>';
  }

  return $html;
}

1;
