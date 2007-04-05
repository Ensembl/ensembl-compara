package EnsEMBL::Web::Commander::Node::UserData;

### Contains methods to create nodes for UserData wizards

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Commander::Node;

our @ISA = qw(EnsEMBL::Web::Commander::Node);

sub start {
  my $self = shift;

  $self->title('Where is the Data?');
  my $text = qq(
<ul class="spaced">
<li>On the internet:
  <ul>
  <li><a href="/common/user_data_wizard?node_name=das_servers;data_type=UserDAS;DASdomain=das.ensembl.org">On an existing DAS server</a></li>
  <li><a href="/common/user_data_wizard?node_name=file">In a file on a web server</a> (URL-based data)</li>
  </ul>
</li>
<li><a href="/common/user_data_wizard?node_name=file">In a file on my local machine</a></li>

<li><a href="/common/user_data_wizard?node_name=account">I have already uploaded it to Ensembl</a> [warning if not logged in]</li>
</ul>
);
  $self->text_above($text);
}

sub das_servers {
  my $self = shift;
  $self->title('Select a Server');

  my $default = $self->object->param("DASdomain");
  my $server_list = $self->object->Obj->get_DAS_server_list($self->object->species_defs, $default);

  $self->add_element(( type => 'DropDown', name => 'server', label => 'Select an existing server',
                            'select' => 'select', value => $default, values => $server_list ));
  $self->add_element(( type => 'String', name => 'filter', label => 'Filter sources by name/URL/description (optional)' ));
  $self->add_element(( type => 'Information', value => 'OR'));
  $self->add_element(( type => 'String', name => 'new_server', label => 'Add another DAS server' ));
}

sub das_sources {
  my $self = shift;

  $self->title('Add Sources');
  ## To Do - get sources dynamically from object
  my @sources = (
  {'value' => 'source_1', 'name' => qq(<h4 class="alt">Source 1</h4><strong>http://db.systemsbiology.net:8080/das/HumanPlasma_ALL_Ens32_P09</strong><br />Peptides from the PeptideAtlas build HumanPlasma_ALL_Ens32_P09<br /><a href="javascript:X=window.open('http://db.systemsbiology.net:8080/das/HumanPlasma_ALL_Ens32_P09', 'DAS source details', 'left=50,top=50,resizable,scrollbars=yes');X.focus();void(0);">details about PeptideAtlas build HumanPlasma_ALL_Ens32_P09</a><br /><br />)},
  {'value' => 'source_2', 'name' => qq(<h4 class="alt">Source 2</h4><strong>http://db.systemsbiology.net:8080/das/Human_2006_06_Ens39_P09</strong><br />Peptides from the PeptideAtlas build Human_P0.9_Ens39_NCBI36<br /><a href="javascript:X=window.open('http://db.systemsbiology.net:8080/das/Human_2006_06_Ens39_P09', 'DAS source details', 'left=50,top=50,resizable,scrollbars=yes');X.focus();void(0);">details about PeptideAtlas build Human_2006_06_Ens39_P09</a><br /><br />)},
  {'value' => 'source_3', 'name' => qq(<h4 class="alt">Source 3</h4>)},
);
  $self->add_element(( type => 'MultiSelect', name => 'source', 'noescape' => 1, class => 'radiocheck1col',
                            values => \@sources ));
  $self->add_element(( type => 'String', name => 'other_source', label => 'Or other DAS source' ));
}

sub finish {
  my $self = shift;

  $self->title('Finished');
  my $point_of_origin;
  $self->destination($point_of_origin);
  $self->text_above("<p>And we're done. All your data are belong to us.");
}


1;


