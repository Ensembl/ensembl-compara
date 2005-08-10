package EnsEMBL::Web::Component::DASCollection;

# Puts together chunks of XHTML for gene-based displays

use EnsEMBL::Web::Component;
use Data::Dumper;

our @ISA = qw(EnsEMBL::Web::Component);

use strict;
use warnings;
no warnings "uninitialized";

my %DASMappingType = (
  'ensembl_gene'          => "Ensembl Gene ID",
  'ensembl_location'      => "Ensembl Location",
  'ensembl_peptide'       => "Ensembl Peptide ID",
  'ensembl_transcript'    => "Ensembl Transcript ID",
  'uniprot/swissprot'     => "Uniprot/Swiss-Prot Name",
  'uniprot/swissprot_acc' => "Uniprot/Swiss-Prot Acc",
  'hugo'                  => "HUGO ID",
  'markersymbol'          => "MarkerSymbol ID",
  'mgi'                   => 'MGI Accession ID',
  'entrezgene'            => 'EntrezGene'
);


my %DASWizard = (
  'das_url' => { 
    TEXT => 'URL based source', 
    FUNC => \&add_das_url,
    HELP => 'data located in a file on a web server'},
  'das_file' => { 
    TEXT => 'Data upload', 
    FUNC => \&add_das_file, 
    HELP => 'Upload your own annotation to ensembl server',
    ENSEMBL_HELP => "javascript:void(window.open('/perl/helpview?se=1&kw=dasconfview#Upload','dasconfview','width=400,height=500,resizable,scrollbars'));"
  },
  'das_server' => {
    TEXT => 'Annotation server', 
    FUNC => \&add_das_server,
    HELP => 'data provided by DAS server',
    ENSEMBL_HELP => "javascript:void(window.open('/perl/helpview?se=1&kw=dasconfview#DSN','dasconfview','width=400,height=500,resizable,scrollbars'));"
  },
  'das_registry' => {
    TITLE => 'Please select <a href="javascript:X=window.open(\'http://das.sanger.ac.uk/registry\', \' \', \'resizable,scrollbars\');X.focus();void(0)">Registry</a> DAS sources to attach:', 
    TEXT => 'DAS Registry server',
    FUNC => \&add_das_registry,
    HELP => 'data provided by DAS server',
    ENSEMBL_HELP => "javascript:void(window.open('/perl/helpview?se=1&kw=dasconfview#DSN','dasconfview','width=400,height=500,resizable,scrollbars'));"
  }
);

my $_select_tmpl = qq(
<select %s> %s
</select> );

my $_option_tmpl = qq(
 <option value="%s" %s> %s </option> );

sub _formelement_select {
    my $input = shift;
    my $name    = shift || die( "Need a formelement name" );
    my $options = shift || die( "Need some option values" );
    my $labels  = shift || {};
    my $attribs = shift || {};
    my $default = shift || '';
    ref( $options ) eq 'ARRAY' || die( "Option values must be an arrayref" );
    ref( $labels  ) eq 'HASH'  || die( "Option labels must be a hashref" );
    my $old_value = ($name =~ /\:(.+)/ ? $input->param($1) : $input->param($name));
    $old_value ||= $default;
    $attribs->{name} = $name;
    my @attribs = map{ sprintf('%s="%s"', $_, $attribs->{$_}) } keys %$attribs;
    my $attrib_str = join( ' ', @attribs );
    my $option_str = '';
    foreach my $opt( @$options ){
    my $selected = $opt eq $old_value ? 'selected' : '';
    my $label    = $labels->{$opt} || $opt;
    $option_str .= sprintf( $_option_tmpl, $opt, $selected, $label );
    }
    return sprintf( $_select_tmpl, $attrib_str, $option_str );
}

sub get_das_domains {
    my ($object) = @_;
    my @domains = ();    
    push( @domains, @{$object->species_defs->ENSEMBL_DAS_SERVERS || []});
    push( @domains, map{$_->adaptor->domain} @{$object->Obj} );
    push( @domains, $object->param("DASdomain") );
    my %known_domains = ( map{ $_ =~ s/^http(s?)\:\/\///; $_=~ s/(\/das)?\/?\s*$/\/das/; $_, 1 } grep{$_} @domains );
    return  sort keys %known_domains;
}

sub get_server_dsns {
    my ($object) = @_;
    my $domain = $object->param('DASdomain');
    $domain =~ s/^http(s?)\:\/\///;

    $object->param('DASdomain', $domain);
    my $protocol = $object->param('DASprotocol') || 'http';

    if( $domain && $protocol ){
        use Bio::EnsEMBL::ExternalData::DAS::DASAdaptor;
        my $adaptor = Bio::EnsEMBL::ExternalData::DAS::DASAdaptor->new
        ( -protocol  => $protocol,
          -domain    => $domain,
          -timeout   => 5,
          -proxy_url => $object->species_defs->ENSEMBL_WWW_PROXY 
          );

        use Bio::EnsEMBL::ExternalData::DAS::DAS;
        my $das = Bio::EnsEMBL::ExternalData::DAS::DAS->new ( $adaptor );
        my @dsns = @{ $das->fetch_dsn_info };
        if( @dsns ){
            return @dsns;
        } else{
            $object->param('_error_das_domain', 'No DSNs for domain');
        }
    } else{
        $protocol || $object->param('_error_das_protocol', 'Need a protocol');
        $domain   || $object->param('_error_das_domain',   'Need a domain');
    }
    return;
}


sub add_das_server {
    my ($form, $source_conf, $object) = @_;
    my @protocols = ( 'http','https' );
    $object->param("DASprotocol") || $object->param("DASprotocol", $protocols[0]);

    $form->add_element( 'type'     => 'Information', 'value'    => 'Please configure your Annotation server' );
    
    my @pvals;
    foreach my $p (@protocols) { push @pvals , {"name"=>"$p://", "value"=>$p}; }
    $form->add_element('type'     => 'DropDown',
                       'select'   => 'select',
                       'name'     => 'DASprotocol',
                       'label'    => 'Protocol',
                       'values'   => \@pvals,
                       'value'    => $object->param("DASprotocol")
                       );



    if (defined($object->param('_das_add_domain.x'))) {
    $form->add_element('type' => 'String',
               'name'     => 'DASdomain',
               'label'    => 'Domain',
               );

    $form->add_element('type' => 'Image',
               'src' => "/img/buttons/dsnlist_small.gif",
               'name' => '_das_list_dsn',
               'value' => 1
               );

    } else {
    my @das_servers = &get_das_domains($object);
    $object->param("DASdomain") or $object->param("DASdomain", $das_servers[0]);
    my $default = $object->param("DASdomain");
    $default =~ s/^http(s?)\:\/\///;

    my @dvals;
    foreach my $dom (@das_servers) { push @dvals, {'name'=>$dom, 'value'=>$dom} ; }

    $form->add_element('type'     => 'DropDown',
               'select'   => 'select',
               'name'     => 'DASdomain',
               'label'    => 'Domain',
               'values'   => \@dvals,
               'value'    => $default, 
               'on_change' => 'submit',
               );
    $form->add_element('type' => 'Image',
               'src' => "/img/buttons/more_small.gif",
               'name' => '_das_add_domain',
               'value' => 1
               );

    my @server_dsns = &get_server_dsns($object);

    my @dsn_values;
    foreach my $dsn ( sort{$a->{dsn} cmp $b->{dsn}} @server_dsns ){
        push @dsn_values, {"name"=>$dsn->{dsn}, "value"=>$dsn->{dsn}};
    }
    $form->add_element(
               'type'     => 'DropDown',
               'select'   => 'select',
               'name'     => 'DASdsn',
               'label'    => 'Data source',
               'values'   => \@dsn_values,
               'value'    => $source_conf->{dsn}
                       );

    }



    $form->add_element(
                       'type'     => 'String',
                       'name'     => 'DASuser_source',
                       'label'    => '(for user uploaded sources enter DSN here)',
                       'value'    => $source_conf->{userdsn}
                       );

    return;
}

sub das_wizard_1 {
    my ($form, $source_conf, $object, $step_ref, $error) = @_;
    my $das_type = $source_conf->{sourcetype};
    return $DASWizard{$das_type}->{FUNC}($form, $source_conf, $object, $step_ref, $error);
}

sub das_wizard {
    my( $panel, $object ) = @_;

    my $html = '';
    foreach my $p ($object->param()) {
        $html .= "$p => ".join('*', $object->param($p))."<br />";
    }

    return if (defined($object->param('_das_submit')));

    my %source_conf = ();        
    my $step;

    my @confkeys = qw( stylesheet strand label dsn caption type depth domain group name protocol labelflag color help url linktext linkurl);

    if (defined(my $new_das = $object->param('_das_add'))) {
        $step = 1;
        $source_conf{sourcetype} = $new_das;
        $object->param('DASsourcetype', $new_das);
    } elsif (defined(my $src = $object->param('_das_edit'))) {
# Editing a source. 
# All parameters are set in &display_wizaard_status of Configuration/DASCollection.pm
# Hence here we just go straight to the last stage of the wizard
        $step = 3;
    $source_conf{sourcetype} = 'das_server';
    }
    if (! defined($step)) {
        $step = $object->param('DASWizardStep');
    }

    return unless (defined ($step));
    if (defined(my $sd = $object->param('_das_Step'))) {
    if ($sd eq 'Next') {
        $step ++;
    } elsif ($sd eq 'Back') {
        $step --;
    }
    }

    foreach my $key (@confkeys) {
        my $hkey = "DAS$key";
        $source_conf{$key} = $object->param($hkey);
    }

    $source_conf{sourcetype} ||= $object->param("DASsourcetype");
    $source_conf{group} ||= 'y';
    $source_conf{user_source} ||= $object->param("DASuser_source");
    @{$source_conf{enable}} = $object->param("DASenable");

    if (my $scount = scalar(@{$source_conf{registry_selection}} = $object->param("DASregistry") || ())) {
    my $dreg = $object->getRegistrySources();
    my %das_list = ();
    my ($prot, $url, $dsn, $dname);
    foreach my $src (@{$source_conf{registry_selection}}) {
        my $dassource = $dreg->{$src};
        $dname = $dassource->{nickname};
        if ($dassource->{url} =~ /(https?:\/\/)(.+das)\/(.+)/) {
        ($prot, $url, $dsn) = ($1, $2, $3);
        $dsn =~ s/\///;
        $das_list{$url}->{$dsn} = $dname;
        }
    }
    $source_conf{shash} = \%das_list;
    $source_conf{scount} = $scount;
    if ($scount > 1) {
        $source_conf{name} = 'As nickname in registry';
        $source_conf{label} = 'As nickname in registry';
    } else {
        $source_conf{name} ||= $dname;
        $source_conf{label} ||= $dname;
    }
    }

    @{$source_conf{mapping}} = $object->param("DAStype");

# If there are more than 1 mapping selected set the source type to mixed 
    if (scalar(@{$source_conf{mapping}}) > 1) {
    $source_conf{type} = 'mixed';
    }
    my $form;

    if ($source_conf{sourcetype} eq 'das_file')  { 
      $form = EnsEMBL::Web::Form->new( 'das_wizard', "/$ENV{ENSEMBL_SPECIES}/dasconfview", 'post');
      $form->add_attribute('ENCTYPE', 'multipart/form-data');
    } else {
      $form = EnsEMBL::Web::Form->new( 'das_wizard', "/$ENV{ENSEMBL_SPECIES}/dasconfview", 'post'); 
    }

    my @cparams = qw ( db gene transcript peptide conf_script c w h bottom);
    foreach my $param (@cparams) {
      warn "$param  ----------- ",$object->param($param);
      if( defined(my $v = $object->param($param)) ) {
        $form->add_element('type'=>'Hidden', 'name' => $param, 'value' => $v );
      }
    }

    no strict 'refs';
    my $fname = "das_wizard_".$step;

    if (defined (my $error = &{$fname}($form, \%source_conf, $object, \$step))) {
    $step --;
    $fname = "das_wizard_".$step;
    &{$fname}($form, \%source_conf, $object, \$step, $error);
    }

    &wizardTopPanel($form, $step, $source_conf{sourcetype});

    $form->add_element('type'=>'Hidden','name' =>'DASWizardStep','value' => $step );

    
    my @sparams; 
    if ($step == 1) {
    @sparams = grep { /^DAS/ && /edit|link|enable|type|name|label|help|color|group|strand|depth|labelflag|stylesheet/} $object->param();
    } elsif ($step == 2) {
    @sparams = grep { /^DAS/ && /edit|link|user_|sourcetype|protocol|domain|dsn|registry|paste_data|name|label|help|color|group|strand|depth|labelflag|stylesheet/} $object->param();
    } elsif ($step == 3) {
    @sparams = grep { /^DAS/ && /edit|user_|protocol|domain|dsn|registry|paste_data|enable|type/} $object->param();
    }
    foreach my $param (@sparams) {
        my @v = $object->param($param);
        foreach my $op (@v) {
            $form->add_element( 'type'=>'Hidden', 'name' => $param,'value' => $op );
        }
    }
 
    $panel->add_columns({ 'key' => 'info', 'title' => ' '    });
#    $panel->add_row( {"info"=>$html} );
    $panel->add_row( {"info"=> $form->render()} );

    return 1;
}


sub added_sources {
    my( $panel, $object ) = @_;

    my $das_collection = $object->get_DASCollection;
    my @das_objs = @{$das_collection};
    my @das_form = ();
    my @url_form = ();

## Sources sorted by type and then by name
    foreach my $das_obj( sort{ ( 3 * ( $b->adaptor->conftype cmp $a->adaptor->conftype ) +  1 * ( lc( $a->adaptor->name ) cmp lc( $b->adaptor->name ))) } @das_objs ){
        my $das_adapt = $das_obj->adaptor;
        my $das_name = $das_adapt->name();
    
        my $das_action = '';
        if( $das_adapt->conftype eq 'internal' ){ # internal DAS source : configured within INI file
            $das_action = '&nbsp;';
        } elsif( $das_adapt->conftype eq 'url' ){ # URL DAS source : no edit, only delete
            my $das_action = sprintf("<a href=\"%s;_urldas_delete=%s\"><image src=\"/img/buttons/del_small.gif\" alt=\"Delete source \'%s\'\"/></a>", $object->param("selfURL"), $das_name, $das_name );
        } else{ # Read-write source; Provide del/edit buttons
            my $delete_link = sprintf("<a href=\"%s;_das_delete=%s\"><image src=\"/img/buttons/del_small.gif\" alt=\"Delete source \'%s\'\"/></a>", $object->param("selfURL"), $das_name, $das_name );
            my $edit_link = sprintf("<a href=\"%s;_das_edit=%s\"><image src=\"/img/buttons/edit_small.gif\" alt=\"Edit source \'%s\'\"/></a>", $object->param("selfURL"), $das_name, $das_name );
            $das_action = $edit_link.$delete_link;
        }

        my $das_url = $das_adapt->url;
        my $das_dsn = $das_adapt->dsn || '&nbsp;';
        my $das_type = $das_adapt->type ? $DASMappingType{$das_adapt->type} || $das_adapt->type : '&nbsp';

# If type is 'mixed' then it is mixed mapping source
        if ($das_type eq 'mixed') {
            $das_type = join('+', map {$DASMappingType{$_}} @{$das_adapt->mapping});
        }

        if ($das_adapt->conftype eq 'url') {
            push @url_form, qq{
  <tr class="background3" valign="middle">
     <td>$das_action</td>
     <td style="padding:3px" >&nbsp;</td>
     <td colspan="3">$das_url</td>
  </tr>
};
        } else {
        push @das_form, {'action'=>$das_action, 'name'=> $das_name, 'url'=>$das_url, 'dsn'=>$das_dsn, 'type'=>$das_type};
        }
            
    }
    
    $panel->add_columns(
                        { 'key' => 'action', 'title' => ' '    },
                        { 'key' => 'name', 'title' => 'Name'    },
                        { 'key' => 'location', 'title' => 'Location' },
                        { 'key' => 'source', 'title' => 'Data source'   },
                        { 'key' => 'mapping', 'title' => 'Mapping type'  },
                        );

    foreach my $src (@das_form) {
        $panel->add_row( {
            'action' => $src->{action},
            'name' => $src->{name},
            'location' => $src->{url}, 
            'source' => $src->{dsn},
            'mapping' => $src->{type},
            '_raw' => $src
            });
    }


    return 1;
}

sub wizardTopPanel {
  my ($form, $step, $stype) = @_;

  my $snum = ($stype eq 'das_url') ? 1 : 3;

  my ($pstage, $nstage) = ();

  if( $step == 10 ) { # Finish
    $form->add_element('type' => 'Submit', 'name'=>'_das_finish', 'value' => 'Finish');
  } elsif ($step == 11) { # Cancel
    $form->add_element('type' => 'Submit', 'name'=>'_das_cancel', 'value' => 'Cancel');
  } elsif ($stype eq 'das_url') {
    $form->add_element('type' => 'Submit', 'name'=>'_das_submit', 'value' => 'Finish');
  } else {
    if( $step > 1 ) {
      $form->add_element('type' => 'Submit', 'name'=>'_das_Step', 'value' => 'Back');
    }
    if( $step < $snum ) {
      $form->add_element('type' => 'Submit', 'name'=>'_das_Step', 'value' => 'Next');
    } else {
      $form->add_element('type' => 'Submit', 'name'=>'_das_submit', 'value' => 'Finish');
    }
  }
  return 1;
}

sub das_wizard_2 {
    my ($form, $source_conf, $object, $step_ref, $error) = @_;

    my $error_section;
    if ($source_conf->{sourcetype} eq 'das_file') {
    my $user_email = $object->param('DASuser_email');
    my $user_password = $object->param('DASuser_password');
    my $user_pastedata = $object->param('DASpaste_data');

# Validate email and password
       
    ( length($user_password) > 0) or $error_section = qq{<strong>ERROR: Empty parameter: Password</strong>};
    
    ($user_email =~ /\@/) or $error_section = qq{<strong>ERROR:Invalid format of Email</strong>};
    return $error_section if ($error_section);

    use EnsEMBL::Web::DASUpload;
    my $du  = EnsEMBL::Web::DASUpload->new($object);
    if (length($user_pastedata) > 0) {
        $du->data($user_pastedata);
    } else {
        $du->upload_data('DASfilename');
    }
    if (defined (my $err= $du->error)) { 
        $error_section = qq{<strong>ERROR: Could not upload data due to \'$err\' </strong>};
    } else {
        if (defined (my $err = $du->parse())) {
        $error_section = qq{<strong>ERROR: Could not upload data due to \'$err\' </strong>};
        } else {
        if (defined(my $user_dsn = $object->param("DASuser_dsn") || undef)) {
            if (defined (my $user_action = $object->param("DASuser_action"))) {
            if ( (my $enum = $du->update_dsn($user_dsn, $user_password, $user_action)) > 0) {
                my $domain = $du->domain;
                my $dsn = $du->dsn;
                $source_conf->{protocol} = 'http';
                $source_conf->{domain} = $domain;
                $source_conf->{dsn} = $dsn;
                
                $object->param('DASprotocol', 'http');
                $object->param('DASdomain', $domain);
                $object->param('DASdsn', $dsn);
                $$step_ref = 10;
                
                $form->add_element('type' => 'Information', 'value'=> qq{
                Successfully uploaded $enum entries <br>
                DAS source at http://$domain/das/$dsn has been updated<hr>
                });

            }
            if (defined (my $err = $du->error)) {
                $error_section = qq{<strong>ERROR: Could not upload data due to \'$err\' </strong>};
            }
            return $error_section;
            } else {
            $error_section = qq{<strong>ERROR: If you want to update the source you have to choose whether to overwrite old data or append new data to them</strong>};
            }
        } else {
            if ( (my $enum = $du->create_dsn($user_email, $user_password)) > 0) {
            my $domain = $du->domain;
            my $dsn = $du->dsn;
            $source_conf->{protocol} = 'http';
            $source_conf->{domain} = $domain;
            $source_conf->{dsn} = $dsn;
            
            $object->param('DASprotocol', 'http');
            $object->param('DASdomain', $domain);
            $object->param('DASdsn', $dsn);
            
            $form->add_element('type' => 'Information', 'value'=> qq{
                Successfully uploaded $enum entries <br>
                A new DAS source has been created at http://$domain/das/$dsn<hr>
            });
            }
            if (defined (my $err = $du->error)) {
            $error_section = qq{<strong>ERROR: Could not upload data due to \'$err\' </strong>};
            }
        }
        }
    }
    return $error_section if ($error_section);
    }
    my $script = $object->param('conf_script');
    
    my %SpeciesID = 
        (
         'Homo_sapiens' => ['hugo'],
         'Mus_musculus' => ['markersymbol', 'mgi']
         );

    my %ExternalIDs = (
                       'hugo'                  => "HUGO ID",
                       'markersymbol'          => "MarkerSymbol ID",
                       'mgi'                => 'MGI Accession ID'
                       );

    my %DASMapping = 
        (
         'ensembl_gene'          => "Ensembl Gene ID",
         'ensembl_location'      => "Ensembl Location",
         'ensembl_peptide'       => "Ensembl Peptide ID",
         'ensembl_transcript'    => "Ensembl Transcript ID",
         'uniprot/swissprot'     => "Uniprot/Swiss-Prot Name",
         'uniprot/swissprot_acc' => "Uniprot/Swiss-Prot Acc",
         'entrezgene' => 'Entrez Gene ID'
         );


    my %DefaultMapping =  (
                           'geneview' => 'ensembl_gene',
                           'protview' => 'ensembl_peptide',
                           'transview' => 'ensembl_gene', # Coz there is no ensembl_transcript source around at the moment
                           'contigview' => 'ensembl_location',
                           'cytoview' => 'ensembl_location'
                           );

       
    if (defined($SpeciesID{$ENV{'ENSEMBL_SPECIES'}})) {
        foreach my $tid (@{$SpeciesID{$ENV{'ENSEMBL_SPECIES'}}}) {
            $DASMapping{$tid} = $ExternalIDs{$tid};
        }
    }

    if ($source_conf->{sourcetype} eq 'das_registry') {
        $form->add_element('type'=>'Information', "label"=> 'Mapping type:', "value"=> 'Provided by Registry');
    } else {
        my @mvalues;
# grep is to filter out undef elements
    my @seltypes = grep {$_} @{$source_conf->{mapping}};
        if (scalar(@seltypes) < 1) {
            push @seltypes, $DefaultMapping{$script};
        }

        my $ptest = join('*', @seltypes).'*';
        foreach my $p (sort keys (%DASMapping)) {
            if ($ptest =~ /$p\*/){
                push @mvalues, {"value"=>$p, "name"=>$DASMapping{$p}, "checked"=>"yes"};
            } else {
                push @mvalues, {"value"=>$p, "name"=>$DASMapping{$p}};
            }
        }
        $form->add_element('type' => 'MultiSelect',
                           'class' => 'radiocheck1col',
                           'name'=>'DAStype',
                           'label'=>'Mapping type',
                           'values' => \@mvalues
                           );
    }
    my @views = ('geneview', 'protview', 'transview', 'contigview', 'cytoview');

    my %selviews = ();
    if (@{$source_conf->{enable}}) {
        foreach (@{$source_conf->{enable}}) {
            $selviews{$_} = 1;
        }
    }

    $selviews{$script} = 1;

    my @vvalues;
    foreach my $v (@views) {
        if ($selviews{$v}) {
            push @vvalues, {"value"=>$v, "name"=>$v, "checked"=>"yes"};
        } else {
            push @vvalues, {"value"=>$v, "name"=>$v};
        }
    }
    $form->add_element('type' => 'MultiSelect',
                       'name'=>'DASenable',
                       'label'=>'Enable on',
                       'values' => \@vvalues
                       );
    return;
}

sub das_wizard_3 {
    my ($form, $das_conf, $object, $step_ref, $error) = @_;

    my $html = qq{<table id="display_config">\n};
    my $option;

    if ($das_conf->{scount} && $das_conf->{scount} > 1) {
    $option = $das_conf->{name};
    $form->add_element('type'=>'Information', 'label'=>'Name:', 'value'=> $option);
    $option = $das_conf->{label} || $option;
    $form->add_element('type'=>'Information', 'label'=>'Track label:', 'value'=> $option);
    } else {
    $option = $das_conf->{name} || $das_conf->{user_source} || $das_conf->{dsn};
    $form->add_element('type'=>'String', 'name'=>'DASname', 'label'=>'Name:', 'value'=> $option);
    $option = $das_conf->{label} || $option;
    $form->add_element('type'=>'String', 'name'=>'DASlabel', 'label'=>'Track label:', 'value'=> $option);
    }

    $option = $das_conf->{help} || '';
    $form->add_element('type'=>'String', 'name'=>'DAShelp', 'label'=>'Help URL:', 'value'=> $option);
    $option = $das_conf->{linktext} || '';
    $form->add_element('type'=>'String', 'name'=>'DASlinktext', 'label'=>'Link Text:', 'value'=> $option);
    $option = $das_conf->{linkurl} || '';
    $form->add_element('type'=>'String', 'name'=>'DASlinkurl', 'label'=>'Link URL:', 'value'=> $option);

    $option = $das_conf->{color} || 'black';

    use Bio::EnsEMBL::ColourMap;
    my $cm = new Bio::EnsEMBL::ColourMap($object->species_defs);
    my @cvalues;
    for $_ (sort keys %$cm) { ## OPTIONS IN DROP DOWN FOR COLOURS
        my $id = $cm->{$_};
        push @cvalues, {'name'=>$_, 'value'=>$_};
    }
    $form->add_element('select'=>'select',
                       'type'=>'DropDown',
                       'name'=>'DAScolor',
                       'label'=>'Track colour',
                       'values'=>\@cvalues,
                       'value' => $option
                       );

    $option = $das_conf->{group} || 'y';
    my @gvalues;
    foreach ( 'Yes', 'No' ) {
        my $id          = lc(substr($_,0,1));
        push @gvalues, {'name'=>$_, 'value'=>$id};
    }
    $form->add_element('select'=>'select',
                       'type'=>'DropDown',
                       'name'=>'DASgroup',
                       'label'=>'Group features',
                       'values'=>\@gvalues,
                       'value' => $option
                       );

    $option = $das_conf->{strand} || 'b';
    my @svalues;
    foreach ( 'Forward strand', 'Reverse strand', 'Both strands' ) {
        my $id          = lc(substr($_,0,1));
        push @svalues, {'name'=>$_, 'value'=>$id};
    }
    $form->add_element('select'=>'select',
                       'type'=>'DropDown',
                       'name'=>'DASstrand',
                       'label'=>'Display on:',
                       'values'=>\@svalues,
                       'value' => $option
                       );

    ## OPTIONS IN DROP DOWN FOR BUMPEDNESS
    $option = defined($das_conf->{depth}) ?  $das_conf->{depth} : 4;
    my @dvalues;
    foreach  ( 0..6,10,20,10000 ) {
        my $id          = $_==0 ? 'Collapse display' : ($_==10000 ? 'Unlimited' : "$_ rows" );
        push @dvalues, {'name'=>$id, 'value'=>$_};
    }

    $form->add_element('select'=>'select',
                       'type'=>'DropDown',
                       'name'=>'DASdepth',
                       'label'=>'Max rows to display:',
                       'values'=>\@dvalues,
                       'value' => $option
                       );

  ## OPTIONS IN DROP DOWN FOR LABELLING
    $option = $das_conf->{labelflag} || 'u';
    my @lbvalues;
    foreach ( 'No label', 'On feature', 'Under feature' ) {
        my $id          = lc(substr($_,0,1));
        push @lbvalues, {'name'=>$_, 'value'=>$id};
    }

    $form->add_element('select'=>'select',
                       'type'=>'DropDown',
                       'name'=>'DASlabelflag',
                       'label'=>'Label features:',
                       'values'=>\@lbvalues,
                       'value' => $option
                       );


    $option = $das_conf->{stylesheet} || 'n';
    my @stvalues;
    foreach ( 'Yes', 'No' ) {
        my $id          = lc(substr($_,0,1));
        push @stvalues, {'name'=>$_, 'value'=>$id};
    }
    $form->add_element('select'=>'select',
                       'type'=>'DropDown',
                       'name'=>'DASstylesheet',
                       'label'=>'Apply stylesheet:',
                       'values'=>\@stvalues,
                       'value' => $option
                       );
    return;
}

sub add_das_registry {
  my ($form, $source_conf, $object) = @_;
  my %selected_sources = ();
  if (defined($source_conf->{registry_selection})) {
    foreach (@{$source_conf->{registry_selection}}) {
      $selected_sources{$_} = 1;
    }
  }

  my $rurl = $object->species_defs->DAS_REGISTRY_URL;

  $form->add_element(
    'type'  => 'Information', 
    'value' => qq{Please select <a href="javascript:X=window.open(\'$rurl\'',\' \', \'resizable,scrollbars\');X.focus();void(0)">Registry</a> DAS sources to attach:}
  );

  my %SpeciesID = (
    'Homo_sapiens' => ['hugo'],
    'Mus_musculus' => ['markersymbol', 'mgi']
  );
    
  my %ExternalIDs = (
    'hugo'                  => "HUGO ID",
    'markersymbol'          => "MarkerSymbol ID",
    'mgi'                => 'MGI Accession ID'
  );
    
  my %DASMapping = (
    'ensembl_gene'          => "Ensembl Gene ID",
    'ensembl_location'      => "Ensembl Location",
    'ensembl_peptide'       => "Ensembl Peptide ID",
    'ensembl_transcript'    => "Ensembl Transcript ID",
    'uniprot/swissprot'     => "Uniprot/Swiss-Prot Name",
    'uniprot/swissprot_acc' => "Uniprot/Swiss-Prot Acc",
    'entrezgene' => "Entrez Gene"
  );
    
  if (defined($SpeciesID{$ENV{'ENSEMBL_SPECIES'}})) {
    foreach my $tid (@{$SpeciesID{$ENV{'ENSEMBL_SPECIES'}}}) {
      $DASMapping{$tid} = $ExternalIDs{$tid};
    }
  }

  $DASMapping{any} = 'Any';
  my $registry = $object->getRegistrySources();

  $rurl .= "/showdetails.jsp?auto_id=";

  my $dwidth = 120;
  my $html = qq{<table>};
  foreach my $id (sort {$registry->{$a}->{nickname} cmp $registry->{$b}->{nickname} } keys (%{$registry})) {
    my $dassource = $registry->{$id};
    my ($id, $name, $url, $desc, $cs) = ($dassource->{id}, $dassource->{nickname}, $dassource->{url}, substr($dassource->{description}, 0, $dwidth), join('*', @{$dassource->{coordinateSystem}}));
    $cs = qq{<a href="javascript:X=window.open(\'$rurl$id\', \'DAS source details\', \'left=50,top=50,resizable,scrollbars=yes\');X.focus();void(0)">details about \`$name\`</a>};
    my $selected = $selected_sources{$id} ? 'checked' : '';
#    $html .= qq{\n  <tr><td><input type="checkbox" name="DASregistry" value="$id" $selected ></td><td>$name</td><td>$url</td><td>$cs</td></tr>};
    
    if( length($desc) == $dwidth ) {
# find the last space character in the line and replace the tail with ...        
      $desc =~ s/\s[a-zA-Z0-9]+$/ \.\.\./;
    }
    $html .= qq{\n  <tr><td><input type="checkbox" name="DASregistry" value="$id" $selected ></td><td>$name</td><td><b>$url</b><br>$desc<br>$cs</td></tr>};
  }

  $html .= qq{\n</table>\n};

  my $mapping_form = &_formelement_select($object, "keyMapping", [ sort keys (%DASMapping) ], {%DASMapping});
  my $das_action = qq{<input type="submit" name="_das_filter" value="Apply" class="red-button" />};

  my $search_box = qq{
<table style="border:0">
  <tr>
    <td nowrap>Name/URL/Description: <input type="text" name="keyText"/></td>
    <td nowrap>Mapping:$mapping_form</td>
    <td valign="top">$das_action</td>
  </tr>
</table>
};
    $html = "$search_box<br>$html";
    $form->add_element( 'type'=>'Information', 'value'=> $html );
    return;
}

sub add_das_file {
  my ($form, $source_conf, $object, $step_ref, $error_section) = @_;

  $form->add_element( 
    'type'  => 'Information',
    'value' => 'Please upload your data location'
  );
  if( $error_section ) {
    $form->add_element(
      'type'  => 'Information',
      'value' => $error_section
    );
  }
  $form->add_element(
    'type'  => 'Information',
    'value' => qq{
  <p>
   Please <strong><a href="javascript:X=window.open('/Homo_sapiens/helpview?se=1&kw=dasconfview#Upload','helpview','left=50,top=50,resizable,scrollbars=yes');X.focus();void(0)">READ THE UPLOAD INSTRUCTIONS CAREFULLY</a></strong> before uploading any data. Your data must be <a href="javascript:X=window.open('/Homo_sapiens/helpview?se=1&kw=dasconfview#UploadFormat','helpview','left=50,top=50,resizable,scrollbars=yes');X.focus();void(0)">formatted correctly</a> before uploads will work properly. The instructions page has detailed information about the data formats.
  </p>
  <p>
    Please read and understand the <a href="javascript:X=window.open('/Homo_sapiens/helpview?se=1&kw=dasconfview#Disclaimer','helpview','left=50,top=50,resizable,scrollbars=yes');X.focus();void(0)">Ensembl policy on uploaded data</a>
  </p>
  <hr />
});
  $form->add_element(
    'type'  => 'Email',
    'name'  => 'DASuser_email',
    'label' => 'Email',
    'value' => $object->param('DASuser_email')
  );

  $form->add_element(
    'type'  => 'String',
    'name'  => 'DASuser_password',
    'label' => 'Password',
    'value' => $object->param('DASuser_password'),
    'notes' => '<small>Enter your email and password to ensure that nobody else can modify your annotation</small>'
  );

  $form->add_element(
    'type'  => 'String',
    'name'  => 'DASuser_dsn',
    'label' => 'Data source',
    'value' => $object->param('DASuser_dsn'),
    'notes' => '<small>If you want to update an existing annotation on Ensembl Server enter <a href="#">its DSN</a> and select your action</small>'
  );
  $form->add_element(
    'type'   => 'DropDown',
    'name'   => 'DASuser_action',
    'label'  => 'Action',
    'values' => [
      { 'name' => 'Overwrite', 'value' => 'Overwrite' },
      { 'name' => 'Append',    'name'  => 'Append'    }
    ]
  );
  $form->add_element(
    'type'  => 'Text',
    'name'  => 'DASpaste_data',
    'label' => 'Paste your data'
  );
  $form->add_element(
    'type'  => 'Information',
    'value' => 'or choose a file to upload'
  );
  $form->add_element(
    'type'  => 'File',
    'name'  => 'DASfilename',
    'label' => "Upload File:"
  );
  return;
}

