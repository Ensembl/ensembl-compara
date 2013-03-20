package EnsEMBL::Web::Document::HTML::NewsArchiveLookup;

### This module outputs a form to select a news archive (Document::HTML::NewsArchive), 
### The functionality was split out in several subs, to make plugin development easier

use strict;

use EnsEMBL::Web::DBSQL::WebsiteAdaptor;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self            = shift;
  my $hub             = $self->hub;
  my $id              = $hub->param('id');
  my $ensembl_version = $hub->species_defs->ENSEMBL_VERSION;
  my @releases        = $self->get_releases(EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub), $hub->species_defs->ENSEMBL_VERSION);
  my $html;
  
  if (@releases) {
    $html .= $self->format_release($_, $id) for @releases;
    $html  = qq{
      <form action="/info/website/news.html" method="get">
        <select name="id">
          $html
        </select> <input type="submit" name="submit" value="Go" />
      </form>
    };
  }
  
  return $html;
}

sub get_releases {
  my ($self, $adaptor, $ensembl_version) = @_;
  return sort { $b->{'id'} <=> $a->{'id'} } grep { $_->{'id'} != $ensembl_version && $_->{'id'} <= $ensembl_version } @{$adaptor->fetch_releases};
}

sub format_release {
  my ($self, $release, $id) = @_;

  my $html = qq(<option value="$release->{'id'}");
  $html   .= ' selected="selected"' if $release->{'id'} == $id;
  $html   .= sprintf '>Release %s (%s)</option>', $release->{'id'}, $release->{'date'};
  
  return $html;
}

1;
