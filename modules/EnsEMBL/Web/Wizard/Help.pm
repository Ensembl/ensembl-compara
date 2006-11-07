package EnsEMBL::Web::Wizard::Help;
                                                                                
use strict;
use warnings;
no warnings "uninitialized";
                                                                                
use EnsEMBL::Web::Wizard;
use EnsEMBL::Web::Form;
                                                                                
our @ISA = qw(EnsEMBL::Web::Wizard);

sub _init {
  my ($self, $object) = @_;
  
  my $sitetype= ucfirst(lc($object->species_defs->ENSEMBL_SITETYPE)) || 'Ensembl';
  
  my @problems = (
      {'value'=>'',   'name' => '-- Select problem type --'},
      {'group' => 'Helpdesk feedback', 'value'=>'Gene structure',   'name' => 'Gene structure'},
      {'group' => 'Helpdesk feedback', 'value'=>'Mapping / Markers','name'  => 'Mapping / Markers'},
      {'group' => 'Helpdesk feedback', 'value'=>'Gene Positioning', 'name'  => 'Gene positioning'},
      {'group' => 'Helpdesk feedback', 'value'=>'Gene Prediction',  'name'  => 'Gene prediction'},
      {'group' => 'Helpdesk feedback', 'value'=>'Protein analysis', 'name'  => 'Protein analysis'},
      {'group' => 'Helpdesk feedback', 'value'=>'Blast',            'name'  => 'Blast'},
      {'group' => 'Helpdesk feedback', 'value'=>'SSAHA',            'name'  => 'SSAHA'},
      {'group' => 'Helpdesk feedback', 'value'=>'BioMart',          'name'  => 'BioMart'},
      {'group' => 'Helpdesk feedback', 'value'=>'Website installation', 'name'  => 'Website installation'},
      {'group' => 'Helpdesk feedback', 'value'=>'Database Installation', 'name'  => 'Database installation'},
      {'group' => 'Helpdesk feedback', 'value'=>'Broken link',             'name'  => 'Broken link'},
      {'group' => 'Helpdesk feedback', 'value'=>'Other general',    'name'  => 'Other general'},
      {'group' => 'Website feedback',  'value'=>'Web problem',      'name'  => 'Web problem'},
      {'group' => 'Website feedback',  'value'=>'Web suggestion',   'name'  => 'Web suggestion'},
      {'group' => 'Website feedback',  'value'=>'Other web feedback', 'name'  => 'Other web feedback'},
  );
 
  ## define fields available to the forms in this wizard
  my %form_fields = (
    'intro' => {
      'type' => 'Information',
      'value' =>'To start searching, either enter a word or phrase in the box below, or select one of the links on the left hand side.',
    },
    'kw' => {
      'type'=>'String', 
      'label'=>'Search for:',
      'required'=>'yes',
    },
    'hilite' => {
      'type'=>'CheckBox', 
      'label'=>'Highlight search terms(s)',
    },
    'name' => {
      'type'=>'String', 
      'label'=>'Your name:',
      'required'=>'yes',
    },
    'email' => {
      'type'=>'Email', 
      'label'=>'Your email:',
      'required'=>'yes',
    },
    'category' => {
      'type'=>'DropDown',
      'select'   => 'select',
      'label'=>'Problem / Query',
      'required'=>'yes',
      'values' => 'problems',
      'value' => $object->param('category'),
    },
    'comments' => {
      'type'=>'Text', 
      'label'=>'Details/comments:',
      'required'=>'yes',
    },
  );

  ## define the nodes available to wizards based on this type of object
  my %all_nodes = (
    'hv_intro' => {
      'form' => 1,
      'title' => "$sitetype Help",
      'input_fields' => [qw(intro kw hilite)],
    },
    'hv_search' => {
      'button' => 'Search',
    },
    'hv_multi' => {
      'page' => 1,
      'title' => 'Search Results',
    },
    'hv_single' => {
      'page' => 1,
    },
    'hv_contact' => {
      'form' => 1,
      'title' => "$sitetype Help",
      'input_fields' => [qw(name email category comments)],
    },
    'hv_email' => {
      'button' => 'Send Email',
    },
    'hv_thanks' => {
      'title' => 'Contact Helpdesk',
      'page' => 1,
    },
  );

  my $data = {
    'problems' => \@problems,
  };

  return [$data, \%form_fields, \%all_nodes];

}

## ---------------------- METHODS FOR INDIVIDUAL NODES ----------------------

sub hv_intro {
  my ($self, $object) = @_;
                                                                                
  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'hv_intro'; 

  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post');
                                                                                
  $wizard->add_widgets($node, $form, $object);
  $wizard->add_buttons($node, $form, $object);
                                                                                
  return $form;
}

sub hv_search {
  my ($self, $object) = @_;
  my %parameter;  

  ## how many search results did we get?
  my $total = scalar(@{$object->results});

  ## NB. This node passes the kw parameter as 'search' in some cases - this is a
  ## bit of a hack to keep the wizard compatible with old Help URLs and thus
  ## avoid broken links

  if (!$total) {
    $parameter{'node'} = 'hv_contact';
    $parameter{'search'} = $object->param('kw');
  }
  elsif ($total > 1) {
    $parameter{'node'}    = 'hv_multi';
    $parameter{'search'}  = $object->param('kw');
    $parameter{'hilite'}  = $object->param('hilite');
    my $i = 0;
    foreach my $article (@{$object->results}) {
      ## messy, but keeps results in order :)
      $parameter{'results'} .= '_' if $i;
      my $id = $$article{'id'};
      my $score = $$article{'score'};
      $parameter{'results'} .= $id.'-'.$score;
      $i++;
    }
  }
  else {
    my $single = $object->results->[0];
    $parameter{'node'}    = 'hv_single';
    $parameter{'kw'}      = $object->param('kw');
    $parameter{'hilite'}  = $object->param('hilite');
    $parameter{'id'}      = $$single{'id'};
    $parameter{'se'}      = 1;
    
  }

  return \%parameter;
}

sub hv_multi {
  ## stub - doesn't need to do anything
}

sub hv_single {
  ## stub - doesn't need to do anything
}

sub hv_contact {
  my ($self, $object) = @_;
                                                                                
  my $wizard = $self->{wizard};
  my $script = $object->script;
  my $species = $object->species;
  my $node = 'hv_contact'; 

  my $form = EnsEMBL::Web::Form->new($node, "/$species/$script", 'post');
                      
  my $kw = $object->param('search');
  if ($kw) {
    $wizard->redefine_node($node, 'title', 'No matches found.');
    $form->add_element(
      'type' => 'Information',
      'value' => qq(Sorry, your search for "$kw" found no matches. [N.B. Very common word such as 'Ensembl' and 'chromosome' are omitted by the search as they appear on almost every page.]<p>If you require more information, please contact us using the form below.</p>),
    );
  }
  ## more backwards compatibility
  if ($object->param('kw')) {
    $kw = $object->param('kw');
  }
                                                          
  $wizard->add_widgets($node, $form, $object);
  $form->add_element(
    'type'  => 'Hidden',
    'name'  => 'kw',
    'value' => $kw,
  );
  $wizard->add_buttons($node, $form, $object);
                                                                                
  return $form;
}

sub hv_email {
  my ($self, $object) = @_;
  my %parameter;  
  
  $object->send_email;
  
  $parameter{'node'} = 'hv_thanks';
                                                                              
  return \%parameter;
}

sub hv_thanks {
  ## stub - doesn't need to do anything
}

1;
