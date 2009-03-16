package EnsEMBL::Web::Component::Account::Interface::NewsfilterList;

### Module to create user news filter list - duh!

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

    $html .= qq(<h3>Your news filters</h3>
    <p>N.B. Currently we only offer the option to filter news by species.</p>);
    ## Sort user filters by name if required

    ## Display user filters
    my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );

    $table->add_columns(
        { 'key' => 'type',      'title' => 'Type',          'width' => '20%', 'align' => 'left' },
        { 'key' => 'options',   'title' => 'Options',       'width' => '40%', 'align' => 'left' },
        { 'key' => 'edit',      'title' => '',              'width' => '20%', 'align' => 'left' },
        { 'key' => 'delete',    'title' => '',              'width' => '20%', 'align' => 'left' },
    );

    foreach my $filter (@filters) {
      my $row = {};
      my @species;
      if (ref($filter->species) eq 'ARRAY') {
        foreach my $sp (@{$filter->species}) {
          push @species, $self->object->species_defs->get_config($sp, 'SPECIES_COMMON_NAME');
        }
      }
      else {
        @species = ($self->object->species_defs->get_config($filter->species, 'SPECIES_COMMON_NAME'));
      }
      $row->{'type'} = 'Species';
      $row->{'options'} = sprintf(qq(<a href="/info/website/news/index.html" title="View News" class="cp-external">%s</a>),
                        join(', ', sort(@species)));

      $row->{'edit'} = $self->edit_link('Newsfilter', $filter->id);
      $row->{'delete'} = $self->delete_link('Newsfilter', $filter->id);
      $table->add_row($row);
      $has_filters = 1;
    }
    $html .= $table->render;
  }


  if (!$has_filters) {
    my $referer = '_referer='.$self->object->param('_referer').';x_requested_with='.$self->object->param('x_requested_with');
    $html .= qq(<p class="center"><img src="/img/help/filter_example.gif" alt="Sample screenshot" title="SAMPLE" /></p>);
    $html .= qq(<p class="center">You do not have any filters set, so you will see general headlines.</p>
<p><a href="/Account/Newsfilter/Add?$referer" class="modal_link">Add a news filter &rarr;</a></p>);
  }

  return $html;
}

1;
