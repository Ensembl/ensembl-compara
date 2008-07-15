package EnsEMBL::Web::Configuration::Interface::News;

### Sub-class to do news-specific interface functions
## TODO: change according to new DB adaptors scheme
use strict;
use EnsEMBL::Web::Data::NewsItem;
use EnsEMBL::Web::Configuration::Interface;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::DBSQL::NewsAdaptor;

our @ISA = qw( EnsEMBL::Web::Configuration::Interface );

sub save {
  my ($self, $object, $interface) = @_;

  my $script = $interface->script_name;
  my ($success, $url);
  
  $interface->cgi_populate($object, $object->param('news_item_id'));
  ## Remove species field to prevent errors
  $interface->data->remove_queriable_field('species_id');
  $success = $interface->data->save;
  
  ## Now save species separately
  my @spp = $object->param('species_id');
  if (scalar(@spp) > 0) {
    my $adaptor = $ENSEMBL_WEB_REGISTRY->newsAdaptor;
    $success = $adaptor->save_item_species($object->param('news_item_id'), \@spp);
  }

  my $id = $ENV{'ENSEMBL_USER_ID'};
  if ($success) {
    ## set timestamp
    if ($id) {
      $interface->data->modified_by($id);
    }
    else {
      $interface->data->created_by($interface->data->id);
    }
    $success = $interface->data->save;

    ## redirect to confirmation page 
    $url = "/$script?dataview=success";
  }
  else {
    $url = "/$script?dataview=failure";
  }
  return $url;
}

1;
