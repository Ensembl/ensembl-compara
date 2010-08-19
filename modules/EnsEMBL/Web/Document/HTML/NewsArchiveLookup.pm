package EnsEMBL::Web::Document::HTML::NewsArchiveLookup;

### This module outputs a form to select a news archive (Document::HTML::NewsArchive), 
### The functionality was split out in several subs, to make plugin development easier

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Hub;
use EnsEMBL::Web::DBSQL::WebsiteAdaptor;

use base qw(EnsEMBL::Web::Document::HTML);

  my EnsEMBL::Web::Hub $hub = undef;
  my $ensembl_version = new EnsEMBL::Web::Hub->species_defs->ENSEMBL_VERSION;
 
 
sub render {
  my $self = shift;
  $hub = new EnsEMBL::Web::Hub;

  
  ## Form for selecting other releases
  return $self->format_releases(
            $self->sort_releases(
              $self->filter(
                $self->get_releases              
              )  
            )
         );
}

sub get_releases{
  my $self = shift;
  my $html;

  ## Form for selecting other releases
  my $adaptor = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub);
  return @{$adaptor->fetch_releases};
}

sub sort_releases{
  my ($self, @releases_to_sort) = @_;
  return sort { $b->{'id'} <=> $a->{'id'} } @releases_to_sort;
}

sub filter{
  my ($self, @releases_to_filter) = @_;
  return grep { ($_->{'id'} != $ensembl_version) && ($_->{'id'} <= $ensembl_version) } @releases_to_filter;
}

sub format_release{
  my ($self, $release)=@_;

  my $formated_html= '<option value="'.$release->{'id'}.'"';
  $formated_html .= ' selected="selected"' if $release->{'id'} == $hub->param('id');
  $formated_html .= sprintf '>Release %s (%s)</option>', $release->{'id'}, $self->pretty_date($release->{'date'}, 'short');
  return $formated_html;
}

sub format_releases{
  my ($self, @releases)=@_;
  my $formated_html;
  if (@releases) {
    $formated_html .= qq(
    <form action="/info/website/news/archive.html" method="get">
      <select name="id">);
    map($formated_html.=$self->format_release($_),@releases);
    $formated_html .= qq(
      </select> <input type="submit" name="submit" value="Go">
    </form>
    );
  }
  return $formated_html  ;
}

1;
