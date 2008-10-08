#######################################################################
#
# Configuration data for the martview UI
#
# Block labels are used for separating the code into logical 'chunks',
# but do not perform any true function
#
# The martview UI is split into 3 'stages': setup, wait, and 'results'
# The display for each stage consists of one or more 'blocks'.
# Each 'block' consists of one or more 'forms'.
# Each 'form' consists of one or more 'entries.
# Each 'entry' is typically a label, a CGI form element, and associated 
# meta data.
#
#######################################################################
package EnsEMBL::Web::BlastView::MetaDataBlast;

use strict;
use Data::Dumper;

use IO::Scalar;
use Bio::SeqIO;

use SiteDefs;
use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::ExtIndex;
use EnsEMBL::Web::BlastView::BlastDefs;

use EnsEMBL::Web::BlastView::Meta;
use EnsEMBL::Web::BlastView::MetaStage;
use EnsEMBL::Web::BlastView::MetaBlock;
use EnsEMBL::Web::BlastView::MetaForm; 
use EnsEMBL::Web::BlastView::MetaFormEntry;
use EnsEMBL::Web::BlastView::MetaHyperlink;

use Bio::Tools::Run::Search;
#use blast_parser::Util qw( get_unique_id );
#use EnsEMBL::Web::BlastView::MetaInstance;
#use vars qw( $GLOBAL $DEFS $SPECIES_DEFS );
our $GLOBAL       = EnsEMBL::Web::BlastView::Meta->new;
our $DEFS         = EnsEMBL::Web::BlastView::BlastDefs->new;
our $SPECIES_DEFS = EnsEMBL::Web::SpeciesDefs->new;
sub config{ return $GLOBAL }

#----------------------------------------------------------------------
STAGE_SETUP:{
  
  my $stage = $GLOBAL->addobj_stage();
  $GLOBAL->set_default_stage($stage);
  $stage->set_name( 'setup' );
  $stage->add_javascript_files( '/blast/ensFormElementControl.js' );
  
  my $block = $stage->addobj_block();
     $block->set_label( qq( Important Notice ) );
  my $form = $block->addobj_form();
     $form->set_type( 'LABEL' );
     $form->set_name( 'alert' );
  my $entry = $form->addobj_form_entry();
     $entry->set_label( qq(We now used Blat as our default DNA search.  This will make your query faster.) );
 BLOCK_SEQUENCE:{
    my $block = $stage->addobj_block();
    $block->set_name('query');
    $block->set_label( qq( Enter the Query Sequence ) );

  FORM_SEQUENCE:{
      my $form = $block->addobj_form();
      $form->set_name('query');
      $form->set_type( 'TEXTAREA_FILE_TEXT_TEXT_AND_RADIO' );
      $form->set_jscript( gen_master_jscript() );

    ENTRY_SEQUENCE:{
	my $entry = $form->addobj_form_entry();
	$entry->set_cgi_name('_query_sequence');
	$entry->set_cgi_rows( 4 );
	$entry->set_cgi_cols( 57 );
	$entry->set_label
	  ( "<B>Either</B> Paste sequences (max 30 sequences) in FASTA or plain text:" );
	#$entry->set_label_summary( $callback );
	$entry->set_cgi_onchange('javascript:changedQuerySequence()');
      }
      
    ENTRY_UPLOAD:{
	my $entry = $form->addobj_form_entry();
	$entry->set_cgi_name('_uploadfile');
	$entry->set_label( "<B>Or</B> Upload a file containing one or more FASTA sequences" );
      }

    ENTRY_ACCESSION:{
        my $entry = $form->addobj_form_entry();
        $entry->set_cgi_name('_pfetch_accession');
        $entry->set_label( "<B>Or</B> Enter a sequence ID or accession ".
                           "(EMBL, UniProt, RefSeq)" );
        my $sp = $SiteDefs::ENSEMBL_PRIMARY_SPECIES;
        # Only enabled if an ENSEMBL_PFETCH_SERVER is configured
        if( ! $SPECIES_DEFS->get_config($sp, 'ENSEMBL_PFETCH_SERVER') ){
          $entry->set_label( '' );
        }
      }
    ENTRY_ACCESSION_SUBMIT:{
        my $entry = $form->addobj_form_entry();
        $entry->set_cgi_name('_pfetch_retrieve');
        $entry->set_value('Retrieve');	
      }

    ENTRY_TICKET_TEXT:{
        my $entry = $form->addobj_form_entry();
        $entry->set_cgi_name('_ticket');
        $entry->set_label
          (sub{
             return $blastview::CGI->param('stage_initialised') ? '' :
               '<B>Or</B> Enter an existing ticket ID:' 
             } );
        #$entry->set_label_summary('Ticket ID: %s');
      }
    ENTRY_TICKET_SUBMIT:{
        my $entry = $form->addobj_form_entry();
        $entry->set_cgi_name('_retrieve');
        $entry->set_value('Retrieve');	
      }
      
    ENTRY_QUERY_TYPES:{
        my @types  = sort $DEFS->dice(-out=>'q_type');
        my $ty_def = $DEFS->default_type;
        
        $form->add_cgi_processing
          (sub{
             my $qt = $blastview::CGI->param('query');
             if( ! $qt ){ return "Need a query type" }
             if( ! grep{ $qt eq $_  } 
                 @types ){ return "Query type '$qt' is invalid" }
             #	     eval{ $blastview::BLAST->seq_type($qt) };
             #	     if( $@ ){ warn( $@ ); return $@; }
             return 0;
           });
        
        foreach my $ty( @types ){
          my $entry = $form->addobj_form_entry();
          $entry->set_value( $ty );
          $entry->set_default( $ty ) if $ty eq $ty_def;
          $entry->set_label( "$ty queries" );
          #$entry->set_cgi_onchange( 'javascript:changedQueryType()' );
          $entry->set_cgi_onclick( 'javascript:changedQueryType()' );
          my $spacer = $form->addobj_form_entry();
        } 
      }
      
      # Process the query
      $form->add_cgi_processing( \&query_processing_callback );
    }

  }

 BLOCK_DATABASE:{
    my $block = $stage->addobj_block();
    $block->set_name('database');
    $block->set_label( qq( Select the databases to search against ) );

  FORM_SPECIES:{
      my $form = $block->addobj_form();
      $form->set_name( 'species' );
      $form->set_type( 'LABEL_WITH_SELECT' );
      $form->add_cgi_processing( \&species_processing_callback );

      my @species  = sort $DEFS->dice(-out=>'species');
      my %valid_sp = map{$_,1} @species;
      my $def_sp   = ( $valid_sp{$SiteDefs::ENSEMBL_PRIMARY_SPECIES} ?
                       $SiteDefs::ENSEMBL_PRIMARY_SPECIES : $species[0] );

    SPECIES_SELECT:{
        my $entry = $form->addobj_form_entry();
        $entry->set_type('SELECT');
        $entry->set_label('Select species:<BR /><SMALL>Use \'ctrl\' key to select multiple species</SMALL>');
        $entry->set_options([@species]);
        $entry->set_default( $def_sp );
        $entry->set_cgi_size(3);
        $entry->set_cgi_multiple(1); # Can select multiple values
        $entry->set_cgi_onchange('javascript:changedSpecies()');
        $entry->set_label_summary( sub{ $blastview::CGI->param('species') } );
      }

#      my $form = $block->addobj_form();
#      $form->set_name( 'species' );
#      $form->set_type( 'CHECKBOX_GROUP' );
#      $form->add_cgi_processing( \&species_processing_callback );      

      # Code ref to return default species
#      $form->set_default
#        (sub{
#           my %valid = map{ $_, 1  } $DEFS->dice(-out=>'species');
#           if( my $sp = $SiteDefs::ENSEMBL_PRIMARY_SPECIES ){
#             $valid{ $sp } && return $sp;
#           }
#           my( $sp ) = sort keys %valid;
#           return $sp;
#         });

#      foreach my $sp( sort $DEFS->dice(-out=>'species') ){
#        my $entry = $form->addobj_form_entry();
#        my $label = $sp;
#        $label =~ s/_/ /;
#        $entry->set_value( $sp );
#        $entry->set_label( $label );
#        $entry->set_label_summary( $label );
#        $entry->set_cgi_onclick('javascript:changedSpecies()');
#      }
    }

  FORM_DATABASE:{
      my $form = $block->addobj_form();
      $form->set_name('database');
      $form->set_type('RADIO_WITH_SELECT');
  
      my @types     = sort $DEFS->dice(-out=>'d_type');
      my $def_ty    = $DEFS->default_type();
      my $def_db    = $DEFS->default_database();
      my %db_labels = $DEFS->database_labels();

      foreach my $type( @types ){
	ENTRY_RADIO:{
	    my $entry = $form->addobj_form_entry();
	    $entry->set_value( $type );
	    $entry->set_label( "$type database" );
	    $entry->set_default( $type ) if $type eq $def_ty;
	    $entry->set_cgi_onclick('javascript:changedDatabaseType()');
	    $entry->set_label_summary
	      (sub{
           my $ty = $blastview::CGI->param('database');
           my $db = $blastview::CGI->param("database_$ty");
           return ( $db_labels{$db} || $db );
	       });
	  }
	ENTRY_SELECT:{
	    my @opts = $DEFS->dice( -d_type=>$type, -out=>'database' );
	    my $entry = $form->addobj_form_entry();
	    $entry->set_name_suffix("_$type");
	    #$entry->set_options( \@opts );
	    $entry->set_default($def_db);
      # Get option labels. Note hack to send abinitio to bottom
	    my $optref = [ map { [$_->[0],$_->[0]] }
                     sort{ $a->[2] <=> $b->[2] || $a->[1] cmp $b->[1] }
                     map { [$_,$db_labels{$_},/ABINITIO/i?1:0] } @opts ];
	    $entry->set_options( $optref );
	    $type = ucfirst $type;
	    $entry->set_cgi_onchange("javascript:changedDatabase$type()");

#	    $entry->set_label_summary("$type database: %s");
	  }
      }

      # Validate datatabase type and database
      $form->add_cgi_processing( \&database_processing_callback );

      #$form->add_cgi_processing( \&database_processing_callback );
    }
  }

 BLOCK_QUERY_METHOD:{
    my $block = $stage->addobj_block();
    $block->set_label( "Select the Search Tool" );
    
  FORM_METHOD:{
      my $form = $block->addobj_form();
      $form->set_name('method'); 
      $form->set_type('SELECT_WITH_BUTTONS');
      $form->add_cgi_processing( \&method_processing_callback );

      my @methods = sort $DEFS->dice( -out=>'method' );

    METHOD_SELECT:{
	my $entry = $form->addobj_form_entry();
	$entry->set_type('SELECT');
	$entry->set_label('<small>Note we now use BLAT as the default DNA search.<br />This will make your queries faster.</small>');
	$entry->set_options([@methods]);
	$entry->set_default( $DEFS->default_method() );
	$entry->set_cgi_size(3);
	$entry->set_cgi_onchange('javascript:changedMethod()');
	$entry->set_label_summary( sub{ $blastview::CGI->param('method') } );
      }
    BUTTON_CONFIGURE:{
	my $entry = $form->addobj_form_entry();
	$entry->set_type('IMAGE2');
	$entry->set_cgi_name('stage');
	$entry->set_value('configure');
#	my $entry = $form->addobj_form_entry();
#	$entry->set_type('IMAGE2');
#	$entry->set_cgi_name('configure');
#	$entry->set_value
#	  (sub{ return $blastview::CGI->param('configure') eq 'on' ?
#		  'off' : 'on' });
      }
    HIDDEN_CONFIGURE:{
	my $entry = $form->addobj_form_entry();
	$entry->set_type('HIDDEN2');
	$entry->set_cgi_name('_configure');
	$entry->set_cgi_processing
	  (sub{
	     my $new = $blastview::CGI->param('configure');
	     my $old = $blastview::CGI->param('_configure');
	     $new && $blastview::CGI->param('_configure', $new) && return;
	     $old && $blastview::CGI->param('configure', $old) && return;
	   });
      }
    ENTRY_RUN:{
	my $entry = $form->addobj_form_entry();
	$entry->set_type('IMAGE2');
	$entry->set_cgi_name('stage');
	$entry->set_value('results_run');
#	$entry->set_cgi_processing
#	  ( sub{ 
#	      # If button pressed, run the blast job!
#	      if( $blastview::CGI->param("_stage_extra") eq 'run' ){
#		eval{ $blastview::BLAST->run };
#		if( $@ ){ warn( $@ ); return $@; }
#	      }
#	      return undef;
#	    } );
      }
    } 
  FORM_SENSITIVITY:{
      my $form = $block->addobj_form();
      $form->set_type( 'LABEL_WITH_SELECT' );
      $form->set_name( 'sensitivity' );

      my @sensitivities = ( [EXACT   => 'Exact matches' ],
                            [LOW     => 'Near-exact matches'],
                            [OLIGO   => 'Near-exact matches (oligo)' ],
                            [SHORT   => 'Near-exact matches (short)' ],
                            [MEDIUM  => 'Allow some local missmatch'],
                            [HIGH    => 'Distant homologies'],
                            [DEFAULT => 'No optimisation' ]);
      my $default = 'LOW'; #TODO get from $DEFS

    SENSITIVITIES_SELECT:{
        my $entry = $form->addobj_form_entry();
        $entry->set_type('SELECT');
        $entry->set_label('Search sensitivity:<BR /><SMALL>'.
                          'Optimise search parameters to find '.
                          'the following alignments</SMALL>');
        $entry->set_options # Callback to add CUSTOM to list
          ( sub{ 
              my @extra = ();
              if( $blastview::CGI->param('sensitivity') eq 'CUSTOM' ){
                push @extra, [CUSTOM => 'Custom optimisation'];
              }
              return( @sensitivities,@extra );
            } );
        $entry->set_default($default);
        $entry->set_label_summary
          ( sub{ ucfirst(lc( $blastview::CGI->param('sensitivity') ) ).
                   ' sensitivity' } );
      }
    }
  }

 BLOCK_ABOUT:{
    my $block = $stage->addobj_block();
    $block->set_name ( qq(about) );
    $block->set_label( qq(About BlastView) );
    
  FORM_ABOUT:{
      my $form = $block->addobj_form();
      $form->set_type( 'LABEL' );
      $form->set_name( 'about' );

    ENTRY_ABOUT:{
	my $entry = $form->addobj_form_entry();
        my $sitetype = ucfirst(lc($SiteDefs::ENSEMBL_SITETYPE));
	$entry->set_label( qq(
<SMALL>BlastView provides an integrated platform for sequence similarity searches against $sitetype databases, offering access to both BLAST and BLAT programs. <BR /><IMG src="/img/blank.gif" height=5 /><BR />
We would like to hear your impressions of BlastView, especially regarding functionality that you would like to see provided in the future. Many thanks for your time. <A href='/info/about/contact/'>[Feedback]</SMALL></A>) );
      }
    }
  }
}

#----------------------------------------------------------------------
STAGE_CONFIGURE:{
  my $stage = $GLOBAL->addobj_stage();
  $stage->set_name( 'configure' );
  $stage->add_javascript_files( '/blast/ensFormElementControl.js' );

  my $sp = $SiteDefs::ENSEMBL_PRIMARY_SPECIES;
  ## Build the old-style hash using the new-style settings
  my %tmp_methods = %{$SPECIES_DEFS->multi_val('ENSEMBL_BLAST_METHODS')||{}};
  my %methods;
  while (my ($k, $v) = each (%tmp_methods)) {
	  next unless ref($v) eq 'ARRAY';
    $methods{$k} = $v->[3];
  }

 BLOCK_RUN:{
    my $block = $stage->addobj_block();
    $block->set_label( "Run Search" );
    my $form = $block->addobj_form();
    $form->set_name('run');
    $form->set_type('1COL_GROUP');
    my $entry = $form->addobj_form_entry();
    $entry->set_type('IMAGE2');
    $entry->set_cgi_name('stage');
    $entry->set_value('results_run');
  }


 BLOCK_CONFIGURE_BY_METHOD:{
    foreach my $me( $DEFS->dice( -out=>'method' ) ){

      # TODO: move this to BlastDefs
      my $method;
      eval{ $method = Bio::Tools::Run::Search->new( -method=>$methods{$me} ) };
      if( $@ ){ warn( $@ ) && next }

      my $param_options;
      eval{ $param_options = $method->parameter_options() };
      if( $@ ){ warn( $@ ) && next }
      ref( $param_options ) eq 'HASH' or next;

      my $block = $stage->addobj_block();
      $block->set_label( "Configuration for $me" );

      $block->set_available
        ( sub{ return $blastview::CGI->param('method') eq $me ? 1 : 0 } );

    FORM_CONFIGURE_PARAMETER:{
        my @param_list = sort{
          $param_options->{$a}->{order} <=> $param_options->{$b}->{order}
        } keys %$param_options;
        my $first=1;
        foreach my $param( @param_list ){
          my $form = $block->addobj_form();
          my $param_data = $param_options->{$param};
          if( $first ){ 
            undef($first);
            $form->add_cgi_processing
              ( sub{ initialise_parameters( $param_options ) } );
          }

          $form->set_name($param);
          $form->set_type('1COL_GROUP');

          my $entry = $form->addobj_form_entry();
          $entry->set_cgi_name( $param );
          my $label = $param_data->{label} || $param;
          if( my $desc = $param_data->{description} ){
            $label .= "<BR /><I><SMALL>$desc</SMALL></I>";
          }
          $entry->set_label( $label );

          $entry->set_default # Callback. Depends on value of sensitivity param
            (sub{
               my $sens = $blastview::CGI->param('sensitivity');
               $sens = uc( $sens );
               if( exists( $param_data->{"default_$sens"} ) ){
                 my $def = $param_data->{"default_$sens"};
                 return defined($def) ? $def : "__OFF__";
               }
               my $def = $param_data->{default};
               return defined($def) ? $def : "__OFF__";
             } );

          if( ref( $param_data->{options} ) ){
            $entry->set_type( 'SELECT' );
            my @opts = @{ $param_data->{options} || [] };
            # Undefined values indicate that the param option should not be 
            # set. This is made explicit by setting the option value in this 
            # case __OFF__
            my @opts = map{ defined($_) ? [$_,$_] : ['__OFF__',''] } @opts; 
            $entry->set_options( [@opts] );
            $entry->set_label_summary
              (sub{ return $blastview::CGI->param($param) ne '__OFF__' ? 
                      "$param:&nbsp;%s" : '' });
          }
          elsif( $param_data->{options} eq 'BOOLEAN' ){
            $entry->set_type( 'CHECKBOX' );
            $entry->set_value(1);
            $entry->set_label_summary
              (sub{ return $blastview::CGI->param($param) ? $param : '' });
          }
          else{
            $entry->set_type( 'TEXT' );
            $entry->set_cgi_maxlength( 20 );
            $entry->set_label_summary
              (sub{ return $blastview::CGI->param($param) ? 
                      "$param:&nbsp;%s" : '' });
          }
        }
      }
    }
  }
}

#----------------------------------------------------------------------

STAGE_RESULTS:{
  my $stage = $GLOBAL->addobj_stage();
  $stage->set_name( 'results' );
  $stage->add_javascript_files( '/blast/ensFormElementControl.js' );

 BLOCK_TICKET:{
    my $block = $stage->addobj_block();
    $block->set_label( 'Retrieve result for ID:' );    
  FORM_TICKET:{
      my $form = $block->addobj_form();
      $form->set_name('ticket');
      $form->set_type('TEXT_AND_SUBMIT');
	
    ENTRY_TICKET_TEXT:{
	my $entry = $form->addobj_form_entry();
	$entry->set_cgi_name('ticket');
	$entry->set_label('');
	$entry->set_cgi_size( 30 );
#	$entry->set_label_summary('Ticket ID: %s');
      }
    ENTRY_TICKET_SUBMIT:{
	my $entry = $form->addobj_form_entry();
	$entry->set_cgi_name('_retrieve');
	$entry->set_value('Retrieve');	
      }
    }
  }

 BLOCK_USAGE:{
    my $block = $stage->addobj_block();
    $block->set_name ( qq(about) );
    $block->set_label( qq(Retrieving Results) );
    
    # Only availavle if ticket has pending jobs
    $block->set_available
      ( sub{ my @pending = ( grep{ $_->status eq 'DISPATCHED' }
			      $blastview::BLAST->runnables );
	     return scalar( @pending ) ? 1 : 0 } );


  FORM_USAGE:{
      my $form = $block->addobj_form();
      $form->set_type( 'LABEL' );
      $form->set_name( 'about' );

    ENTRY_USAGE:{
	my $entry = $form->addobj_form_entry();
	$entry->set_label( qq( 
<SMALL>'Job pending' results can be retrieved by clicking on the button above. Alternatively, this page can be bookmarked for later, or the ID noted and entered on the BLAST page.<br/><IMG src="/img/blank.gif" height=5 /><br/>
Results are retained for 7 days. After this, they must be re-submitted.) );
      }
    }
  }

 BLOCK_VIEW_OPTIONS:{
    my $block = $stage->addobj_block();
    $block->set_label( 'Alignment Display Options:' );    

    # Only availavle if ticket has completed jobs that have alignments
    $block->set_available
      ( sub{ my @complete = ( grep{ $_->status eq 'COMPLETED' }
			      $blastview::BLAST->runnables );
	     scalar( @complete ) || return 0;
	     map{ $_->result->num_hits > 0 && return 1 } @complete;
	     return 0 } );

  FORM_VIEW_OPTIONS:{
      my $form = $block->addobj_form();
      $form->set_name('view');
      $form->set_type('2CONTROL_GROUP');
      
    ENTRY_KARYOTYPE:{
        my $entry = $form->addobj_form_entry();
        $entry->set_cgi_name('viewreskaryo');
        $entry->set_value(1);
        $entry->set_default(1);
        $entry->set_type('CHECKBOX');
        $entry->set_label('Locations vs. Karyotype');
      }
    ENTRY_HIT_TABLE:{
        my $entry = $form->addobj_form_entry();
        $entry->set_cgi_name('viewresaligngraph');
        $entry->set_value(1);
        $entry->set_default(1);
        $entry->set_type('CHECKBOX');
        $entry->set_label('Locations vs. Query');
      }
    ENTRY_HSP_TABLE:{
        my $entry = $form->addobj_form_entry();
        $entry->set_cgi_name('viewressummary');
        $entry->set_value(1);
        $entry->set_default(1);
        $entry->set_type('CHECKBOX');
        $entry->set_label('Summary Table');
      }
#    ENTRY_HSP_INFO:{
#	my $entry = $form->addobj_form_entry();
#	$entry->set_cgi_name('viewhspinfo');
#	$entry->set_value(1);
#	$entry->set_default(0);
#	$entry->set_label('HSP Info');
 #     }            
#    ENTRY_HSP_ALIGNMENT:{
#	my $entry = $form->addobj_form_entry();
#	$entry->set_cgi_name('viewhspalign');
#	$entry->set_value(1);
#	$entry->set_default(0);
#	$entry->set_label('HSP Alignment');
#      }      
#    ENTRY_QUERY_MARKUP:{
#	my $entry = $form->addobj_form_entry();
#	$entry->set_cgi_name('viewquery');
#	$entry->set_value(1);
#	$entry->set_default(0);
#	$entry->set_label('Query Sequence Markup');
#      }      
#    ENTRY_HIT_MARKUP:{
#	my $entry = $form->addobj_form_entry();
#	$entry->set_name_suffix('_hit_markup');
#	$entry->set_value(1);
#	$entry->set_default(0);
#	$entry->set_label('Hit Sequence Markup');	
#      }
    }
  }
}

#----------------------------------------------------------------------

STAGE_DISPLAY:{
  my $stage = $GLOBAL->addobj_stage();
  $stage->set_name( 'display' );
}



#----------------------------------------------------------------------
# Callback run by EmsMart::MetaForm->run_cgi_processing
# Uses the $blastview::CGI (CGI) and $blastview::BLAST (RunMulti) variables
sub query_processing_callback{

  my $cgi   = $blastview::CGI;
  my $blast = $blastview::BLAST;

  my $changed=0;

  my $method = $cgi->param('method');

  my %max_lengths = ( SSAHA   => 50000,
		      SSAHA2  => 50000,
		      DEFAULT => 200000 );
  my $max_length=$max_lengths{$method} || $max_lengths{DEFAULT};
  my $max_number=30;

  # Load from file upload
  if( my $fh = $cgi->param('_uploadfile') ){ 
    map{ $blast->remove_seq($_->display_id) } $blast->seqs; # Remove existing
    my $seq_io = Bio::SeqIO->new(-fh=>$fh );
    my $i = 0;
    while( my $seq = $seq_io->next_seq ){
      if( $i > $max_number ){ last }
      eval{ $blast->add_seq($seq) };
      if( $@ ){ return $@ }
    }
    $changed = 1;
  }
  
  elsif( my $id = $cgi->param('_pfetch_accession') or
         $cgi->param('_pfetch_retrieve') ){
    map{ $blast->remove_seq($_->display_id) } $blast->seqs; # Remove existing
    $id || return "Need a sequence ID";
    my $indexer = EnsEMBL::Web::ExtIndex->new( $SPECIES_DEFS );
    my $seq = join( "", @{$indexer->get_seq_by_id({DB=>"PUBLIC",
                                                   ID=>$id})} );
    if( ! $seq or $seq =~ /^no match/ ){
      $seq = join( "", @{$indexer->get_seq_by_acc({DB=>"PUBLIC",
                                                   ACC=>$id})} );
      if( ! $seq or $seq =~ /^no match/ ){
        return "Sequence ID $id was not found";
      }
    }
    if( $seq !~ /^>/ ){ $seq = ">$id\n".$seq }
    my $fh = IO::Scalar->new(\$seq);
    my $seq_io = Bio::SeqIO->new(-fh=>$fh );
    my $bioseq = $seq_io->next_seq;
    eval{ $blast->add_seq($bioseq) };
  }

  # Load from sequence string
  elsif( my $seq = $cgi->param('_query_sequence') and
	 $cgi->param('_query_sequence') !~ /^\*\*\*/o ){
    map{ $blast->remove_seq($_->display_id) } $blast->seqs; # Remove existing
    $seq =~ s/^\s+//;
    if( $seq !~ /^>/ ){ $seq = ">unnamed\n".$seq }
    my $fh = IO::Scalar->new(\$seq);
    my $seq_io = Bio::SeqIO->new(-fh=>$fh );
    my $i = 0;
    while( my $bioseq = $seq_io->next_seq ){
      if( $i > $max_number ){ last }
      eval{ $blast->add_seq($bioseq) };
      if( $@ ){ return $@ }
    }
    $changed = 1;
  }

  #Max sequence length check
  my $max_length_error = 0;
  my @seqs        = ();
  foreach my $seq( $blast->seqs ){
    $seq->length > $max_length ? unshift @seqs, $seq : push @seqs, $seq;
    #warn( ">>> ",$seq->alphabet );
  }

  my $num_seqs = scalar( @seqs );
  $cgi->param( 'num_sequences',  $num_seqs); # Keep tally

  if( $num_seqs < 1 ){
    return "No query sequences have been entered";
  }

  #if( ! $changed ){ return }

  # Construct the _query_sequence summary  
  my $htmpl = qq(
***QUERY INFO: %s %s SEQUENCE\(S\)***\n);
  
  my $tmpl = qq/
Seq %s: %s (%s letters)%s/;

  my $str = sprintf
    ( $htmpl, $num_seqs, uc( $cgi->param("query") ) );
  
  my $i = 0;
  foreach my $seq( @seqs ){
    #    warn( Dumper $qseq );
    my $length_warn = '';
    if( $seq->length > $max_length ){ 
      $length_warn = " Too long!"; 
      $max_length_error ++;
    }
    $i++;
    $str .= sprintf
      ( 
       $tmpl, 
       $i, $seq->display_id, $seq->length, $length_warn  
      );
  }
  $cgi->param('_query_sequence', $str );

  if( $num_seqs > $max_number ){
    return( "No queries submitted: ".
	    "The maximum number of query sequences ($max_number) ".
	    "has been exceeded. " );
  }

  if( $max_length_error ){ 
    return( "No queries submitted: ".
	    "The maximum length for a single query sequence ".
	    "($max_length bp for $method) ".
	    "has been exceeded" );
  }

  return;
}

#----------------------------------------------------------------------
my $sp = $SiteDefs::ENSEMBL_PRIMARY_SPECIES;
my %tmp_methods = %{$SPECIES_DEFS->multi_val('ENSEMBL_BLAST_METHODS')||{}};
my %methods;
while (my ($k, $v) = each (%tmp_methods)) {
	next unless ref($v) eq 'ARRAY';
  $methods{$k} = $v->[3];
}

sub method_processing_callback{

  my $cgi   = $blastview::CGI;
  my $blast = $blastview::BLAST;

  my $qt = $cgi->param('query')        || return "";
  my @sp = $cgi->param('species'); scalar( @sp ) || return '';
  my $dt = $cgi->param('database')     || return "";
  my $db = $cgi->param("database_$dt") || return "";
  my $me = $cgi->param('method')       || return "Need a method";

  my $changed_qt = $cgi->param('_changed_query')        ? 1 : 0;
  my $changed_sp = $cgi->param('_changed_species')      ? 1 : 0;
  my $changed_dt = $cgi->param('_changed_database')     ? 1 : 0;
  my $changed_db = $cgi->param("_changed_database_$dt") ? 1 : 0;
  my $changed_me = $cgi->param('_changed_method')       ? 1 : 0;
  my $changed_se = $cgi->param('_changed_sensitivity' ) ? 1 : 0;

  # test config validity of method
  foreach my $sp( @sp ){
    my( $test ) = $DEFS->dice( -q_type  =>$qt, 
			       -d_type  =>$dt,
			       -species =>$sp,
			       -database=>$db,
			       -method  =>$me );
    $test || return "Method '$me' is invalid";
  }

  # Get current method
  my $method;
  eval{ ( $method ) = $blast->methods };
  if( $@ ){ warn( $@ ) && return "Ensembl system error" }

  # Only set method if we have a new one
  if( ! $method or $changed_me or $changed_se){

    # Remove existing methods from job
    foreach( $blast->methods ){
      my $id = $_->id;
      eval{ $blast->remove_method($id) };
      if( $@ ){ warn( $@ ) &&  return "Can't remove method $id" }
    }

    # Create a new method object
    eval{ $method = Bio::Tools::Run::Search->new(-workdir=> $blast->workdir(),
						 -method=>$methods{$me} ) };
    if( $@ ){ warn( $@ ) &&  return "Can't use $me. Ensembl system error!" }

    # Add the new method
    $method->id( $me );
    eval{ $blast->add_method($method) };
    if( $@ ){ warn( $@ ) &&  return "Can't use $me. Ensembl system error!" }

    # Clean up parameters for this method/sensitivity vs old
    my $sensitivity  = uc( $cgi->param( 'sensitivity' ) );
    my $params = $method->parameter_options() || {};
    foreach my $param( keys %$params ){
      my $existing_val = $cgi->param( $param ); #TODO save value?
      next if $sensitivity eq 'CUSTOM' and defined $existing_val;
      my $def = undef;
      if( exists( $params->{$param} ) ){
        if( exists( $params->{$param}->{"default_$sensitivity"} ) ){
          $def = $params->{$param}->{"default_$sensitivity"}
        } elsif( exists( $params->{$param}->{"default"} ) ){
          $def = $params->{$param}->{"default"}
        }
      }
      $cgi->param( -name=>$param, -value=>[$def] );
    } 

  }
  
  # Set method priority based on num species and num dbs
  my $num_dbs  = scalar( @sp );
  my $num_seqs = scalar( $blast->seqs );
  my $num_jobs = $num_dbs * $num_seqs;
  my $priority;
  if   ( $num_jobs < 5  ){ $priority = 'offline'  }#'blast_test' }
  elsif( $num_jobs < 15 ){ $priority = 'slow'     }#'blast_test' }
  else                   { $priority = 'basement' }#'blast_test' }
  $method->priority( $priority );

  # Only set databases if species or databases changed
  my %existing_dbs = map{$_, 1} $blast->databases;
  if( scalar( %existing_dbs  ) and 
      ! $changed_sp and 
      ! $changed_dt and
      ! $changed_db ){
    return 0;
  }
  
  # Update BLAST
  foreach my $sp( @sp ){
    my $database = $sp.'_'.$db;
    
    if( $existing_dbs{$database} ){ 
      delete( $existing_dbs{$database} );
      next;
    }

    
    
    eval{ $blast->add_database($database) };
    if( $@ ){ warn( $@ ); return $@; }
  }
  map{ $blast->remove_database($_) } keys %existing_dbs;

  return 0;
}

#----------------------------------------------------------------------
# Called by the PARAMETERS cgi_processing callback
# 2. Checks that parameter is available for the current method
# 3. Resets the method if there are running searches for the method
# 4. Returns the parameter value
sub initialise_parameters{
  my $param_options = shift;
  my @param_list = sort{
    $param_options->{$a}->{order} <=> $param_options->{$b}->{order}
  } keys %$param_options;  

  # Is there anything to do?
  my $reset = 0;
  foreach( @param_list ){
    $blastview::CGI->param("_changed_$_") && $reset++ && last();
  }
  $reset ||= $blastview::CGI->param("_changed_method");
  $reset ||= $blastview::CGI->param("_changed_sensitivity");
  $reset ||= ! $blastview::CGI->param("parameter_defaults");
  $reset || return; # Nothing to do at this time
  $blastview::CGI->param(-name=>"parameter_defaults", -value=>1 );

  # Get search factory, and reset if already running
  my( $factory ) = $blastview::BLAST->methods;
  $factory || return "No method set: cannot continue";
  $blastview::BLAST->remove_method( $factory->id );
  $factory = $factory->new();
  $blastview::BLAST->add_method( $factory );

  # Delete all old params
  map{ $factory->option($_,undef()) } $factory->option;

  my $sensitivity = uc( $blastview::CGI->param('sensitivity') );
  foreach my $param( @param_list ){
    my $param_meta = $param_options->{$param};
    my $new_val    = $blastview::CGI->param($param);

    if( $new_val eq '__OFF__' ){ undef( $new_val ) } # Disable parameter option

    # Deal with sensitivity
    my $def = $param_meta->{default};
    if( exists( $param_meta->{"default_$sensitivity"} ) ){
      $def = $param_meta->{"default_$sensitivity"};
    }

    my( @numdef ) = grep{ defined($_) } ( $def, $new_val ); #Custom if only 1
    if( @numdef == 1 or $new_val ne $def ){ # Custom sensitivity
      $blastview::CGI->param('sensitivity','CUSTOM');
    }
    if( $param_meta->{options} eq 'BOOLEAN' ){
      my $opt_val = $new_val ? '' : undef(); # Empty string to enable, 
                                             # undef to disable
      eval{ $factory->option( $param, $opt_val ) };
      if( $@ =~ /MSG:\s(.+)/ ){ warn($@) && return $1 }
      if( $@ ){ warn($@) && return $@ }
    }
    else{
      eval{ $factory->option( $param, $new_val )};
      if( $@ =~ /MSG:\s(.+)/ ){ warn($@) && return $1 }
      if( $@ ){ warn($@) && return $@ }
    }
  }
  return;
}


#----------------------------------------------------------------------
#
sub species_processing_callback{
  # Collate info
  my $cgi = $blastview::CGI;
  my $qt  = $cgi->param('query');
  my $me  = $cgi->param('method');
  my @sp  = grep{ $_ } $cgi->param('species');
  if( ! @sp ){ return "Need a species" }
  # Validate
  my %va = map{$_,1} $DEFS->dice( -q_type =>$qt, -method =>$me,
				  -out=>'species' );
  my @bad = grep{ ! $va{$_} } @sp;
  if( @bad ){
    my $bstr = "'".( join "', '", @bad )."'";
    return "Species $bstr is/are invalid";
  }
  return undef;
}

#----------------------------------------------------------------------
#
sub database_processing_callback{

  my $cgi   = $blastview::CGI;
  my $blast = $blastview::BLAST;

  my $qt  = $cgi->param('query');
  my $me  = $cgi->param('method');
  my @sp  = $cgi->param('species');
  scalar( @sp ) || return( "" );
  my $dt  = $cgi->param('database')      || return "Need a database type";
  my $db  = $cgi->param("database_$dt" ) || return "Need a database";

  # Validate type
  my %va = map{$_,1} $DEFS->dice( -q_type=>$qt,
				  -d_type=>$dt, -out=>'species' );
  if( grep{ ! $va{$_} } @sp ){
    return "Database type '$dt' is invalid";
  }
  # Validate database
  %va = map{$_,1} $DEFS->dice( -q_type=>$qt, 
			       -d_type=>$dt, -database=>$db, 
			       -out=>'species' );
  if( grep{ ! $va{$_} } @sp ){
    return "Database '$dt' is invalid";
  }
  
  return 0;
}

#----------------------------------------------------------------------
# Builds javascript code for the 'SETUP' stage
sub gen_master_jscript{

  my @species       = sort $DEFS->dice(-out=>'species');
  my @databases     = sort $DEFS->dice(-out=>'database');
  my @methods       = sort $DEFS->dice(-out=>'method');
  my @types         = sort $DEFS->dice(-out=>'d_type');#all_types();
  my @sensitivities = qw( EXACT LOW OLIGO SHORT MEDIUM HIGH DEFAULT );

  # Sort databases to push abinitio DBs to bottom of list and latestgp to top.
  @databases = ( map { $_->[1] }
                 sort{ $a->[0] <=> $b->[0] || $a->[1] cmp $b->[1] } 
                 map { [/ABINITIO/i?1:/LATESTGP/i?-1:0,$_] } @databases );

  # Sort databases by labels
  my %db_labels = $DEFS->database_labels();
  @databases = sort{uc($db_labels{$a}) cmp uc($db_labels{$b})} @databases;  

  my $js_species       = '"'. join('","', @species       )   .'"';
  my $js_databases     = '"'. join('","', @databases     ) .'"';
  my $js_methods       = '"'. join('","', @methods       )   .'"';
  my $js_types         = '"'. join('","', @types         )   .'"';

  my $js_ary1 = "
methodConf[\"%s\"] = new Array();";
  my $js_ary2 = "
methodConf[\"%s\"][\"%s\"] = new Array();";
  my $js_ary3 = "
methodConf[\"%s\"][\"%s\"][\"%s\"] = new Array();";
  my $js_ary4 = "
methodConf[\"%s\"][\"%s\"][\"%s\"][\"%s\"] = new Array();";
  my $js_ary5 = "
methodConf[\"%s\"][\"%s\"][\"%s\"][\"%s\"][\"%s\"] = 1;";

  my $js_sens_ary1 = "
sensitivityConf[\"%s\"] = new Array();";
  my $js_sens_ary2 = "
sensitivityConf[\"%s\"][\"%s\"] = 1;";

  my $js_method_conf = '';
  foreach my $qt( $DEFS->dice(-out=>'q_type') ){
    $js_method_conf .= sprintf( $js_ary1, $qt);

    foreach my $sp( $DEFS->dice(-q_type => $qt,
                                -out    => 'species' ) ){
      $js_method_conf .= sprintf( $js_ary2, $qt, $sp );
      foreach my $dt( $DEFS->dice(-q_type => $qt,
                                  -species=> $sp,
                                  -out    => 'd_type' ) ){
        $js_method_conf .= sprintf( $js_ary3, $qt, $sp, $dt );
        foreach my $db( $DEFS->dice(-q_type => $qt,
                                    -species=> $sp,
                                    -d_type => $dt,
                                    -out    => 'database' ) ){
          $js_method_conf .= sprintf( $js_ary4, $qt, $sp, $dt, $db );
          foreach my $me( $DEFS->dice(-q_type  => $qt,
                                      -species => $sp,
                                      -d_type  => $dt,
                                      -database=> $db,
                                      -out     => 'method' ) ){
            $js_method_conf .= sprintf( $js_ary5, $qt, $sp, $dt, $db, $me );
          }
        }
      }
    }
  }
#warn Dumper($js_method_conf);
  # TODO: get sensitivity data into $DEFS!
  my $js_sensitivity_conf = '';
  foreach my $me( @methods ){
    $js_sensitivity_conf .= sprintf( $js_sens_ary1, $me);
    my @sensitivities = qw( LOW MEDIUM HIGH EXACT );
    if( uc($me) eq 'BLASTN' ){
      push @sensitivities, 'OLIGO';
    }
    elsif( uc($me) eq 'BLASTP' or uc($me) eq'TBLASTN' ){
      push @sensitivities, 'SHORT';
    }
    elsif( uc($me) eq 'SSAHA' ){ @sensitivities = qw( LOW EXACT ) }
    elsif( uc($me) eq 'SSAHA2' ){ @sensitivities = qw( LOW EXACT ) }
    foreach my $sens( @sensitivities ){
      $js_sensitivity_conf .=sprintf( $js_sens_ary2, $me, $sens )
    }
    $js_sensitivity_conf .=sprintf( $js_sens_ary2, $me, 'DEFAULT' );
    $js_sensitivity_conf .=sprintf( $js_sens_ary2, $me, 'CUSTOM' );
  }

#  my $js_lab_tmpl = "\n  %s['%s'] = '%s';";  
#  my %db_labels = $DEFS->database_labels();
#  my $js_method_labels = '';
#  foreach my $db( @databases ){
#    $js_method_labels .= sprintf( $js_lab_tmpl,
#                                  "methodLabels",
#                                  $db, ( $db_labels{$db} || $db ) );
#  }

return "
<script type=\"text/javascript\">
<!--//--><![CDATA[//><!--
//----------------------------------------------------------------------
// Define global constants

var typeAry        = new Array( $js_types );
var methodAry      = new Array( $js_methods );
var sensitivityValues = new Array();
var speciesAry     = new Array( $js_species );
var databaseAry    = new Array( $js_databases );

var methodConf        = new Array();
var sensitivityConf   = new Array();
var methodLabels      = new Array();
var sensitivityLabels = new Array();
var dbDnaLabels       = new Array();
var dbPeptideLabels   = new Array();

initMethodConf();
initSensitivityConf();
setAll();

var lastQueryType       = getQueryType();
var lastMethod          = getMethod();
var lastSensitivity     = getSensitivity();
var lastSpecies         = getSpecies();
var lastDatabaseType    = getDatabaseType();
var lastDatabaseDna     = getDatabaseDna();
var lastDatabasePeptide = getDatabasePeptide();
var defaultQueryType       = lastQueryType;
var defaultMethod          = lastMethod;
var defaultSensitivity     = lastSensitivity;
var defaultSpecies         = lastSpecies;
var defaultDatabaseType    = lastDatabaseType;
var defaultDatabaseDna     = lastDatabaseDna;
var defaultDatabasePeptide = lastDatabasePeptide;
//debug();

//----------------------------------------------------------------------
// Initialises the methodConf data
//
function initMethodConf(){
  $js_method_conf
  var dbDnaSelect = document.settings.database_dna;
  if( dbDnaSelect ){
    for( var i=0; i<dbDnaSelect.length; i++ ){
      dbDnaLabels[dbDnaSelect[i].value]=dbDnaSelect[i].text;
    }
  }

  // method labels
  var meSelect = document.settings.method;
  if( meSelect ){
    for( var i=0; i<meSelect.length; i++ ){
      methodLabels[meSelect[i].value]=meSelect[i].text;
    }
  }

  // db Labels
  var dbPeptideSelect = document.settings.database_peptide;
  if( dbPeptideSelect ){
    for( var i=0; i<dbPeptideSelect.length; i++ ){
      dbPeptideLabels[dbPeptideSelect[i].value]=dbPeptideSelect[i].text;
    }
  }
}

//----------------------------------------------------------------------
// Initialises the sensitivityConf data
//
function initSensitivityConf(){
  $js_sensitivity_conf
  var sensSelect = document.settings.sensitivity;
  if( sensSelect ){
    for( var i=0; i<sensSelect.length; i++ ){
      sensitivityValues.push(sensSelect[i].value);
      sensitivityLabels[sensSelect[i].value]=sensSelect[i].text;
    }
  }
}


//----------------------------------------------------------------------
// Determines whether there is any values in the methodConf array for
// the given queryType, method, species, and returs it
//
function getConf( queryType, species, databaseType, database, method ){

  var level1 = queryType;
  var level2 = species;
  var level3 = databaseType;
  var level4 = database;
  var level5 = method;

  // Does methodConf contain data? continue?
  if( methodConf ){

    // Do we have a level1 value? if not, just return the methodConf
    if( ! level1 ){ return methodConf; }

    // Does the level1 value have conf data? 
    if( methodConf[level1] ){
      
      // Do we have a level2 value if not, just return the level1 conf
      var level1Ary = methodConf[level1];
      if( ! level2 ){ return level1Ary; }

      // Does the level2 value have conf data? 
      if( level1Ary[level2] ){
 
        // Do we have a level 3 value? if not, just return the level2 conf
        var level2Ary = level1Ary[level2];
        if( ! level3 ){ return level2Ary; }

        // Does the level3 value have conf data?
        if( level2Ary[level3] ){
          
          // Do we have a level4 value? if not, just return the level3 conf
          var level3Ary = level2Ary[level3];
          if( ! level4 ){ return level3Ary }

          //Does the level4 value have conf data?
          if( level3Ary[level4] ){

            // Do we have a level5 value? if not, just return the level4 conf
            var level4Ary = level3Ary[level4];
            if( ! level5 ){ return level4Ary }

            // Done!
            return level4Ary[level5];
          }
        } 
      }
    }
  }
  // Failed - no conf data to return
  return false;
}

//----------------------------------------------------------------------
// Sets all form elements
//
function setAll(){
  setQueryType();
  setSpecies();
  setDatabaseType();
  setDatabase();
  setMethod();
  setSensitivity();
  return;
}

//----------------------------------------------------------------------
// Runs the required routines when qeryType has changed
//
function changedQueryType(){
  setSpecies();
  setDatabaseType();
  setDatabase();
  setMethod();
  setSensitivity();
  return;
}

//----------------------------------------------------------------------
// Runs the required routines when species has changed
//
function changedSpecies(){
  setDatabaseType();
  setDatabase();
  setMethod();
  setSensitivity();
  return;
}

//----------------------------------------------------------------------
// Runs the required routines when database has changed
//
function changedDatabaseType(){
  setMethod();
  setSensitivity();
  return;
}

//----------------------------------------------------------------------
// Runs the required routines when database_dna has changed
//
function changedDatabaseDna(){
  var dt = getDatabaseType();
  if( dt != 'dna' ){ return }
  setMethod();
  setSensitivity();
  return;
}

//----------------------------------------------------------------------
// Runs the required routines when database_peptide has changed
//
function changedDatabasePeptide(){
  var dt = getDatabaseType();
  if( dt != 'peptide' ){ return }
  setMethod();
  setSensitivity();
  return;
}



//----------------------------------------------------------------------
// Runs the required routines when qeryType has changed
//
function changedMethod(){
  setSensitivity();
  return;
}


//----------------------------------------------------------------------
// Sets the query type depending on query sequence
//
function changedQuerySequence( ){
  //alert( \"setQueryType\" );
  var sequence = document.settings._query_sequence.value;
  var letters = 0;
  var count = 0;
  var residue = \"\";
  var percentage;
  var sequence_to_check;
  var spaces = 0;
  var bases = \"ACGTNX\";
  var base_found;
  var space_or_digits = '01234 56789';
  var space_or_digit_found;
  var dna_threshold = 85;

// **********************************************************************
// count                holds the cumulative number of \"ACGTNX\"
// residue              single residue in the sequence 
// percentage           the % of the sequence that is \"ACGTNX\"
// def_line_end         position of the end of the definition line
// sequence_to_check    sequence without the definition line
// spaces               number of spaces or digits found
// bases                valid list of bases
// base_found           was a valid base found?
// space_or_digits      invalid chars 
// space_or_digit_found was an invalid char found?
// **********************************************************************

  var seqLength = 1000;
  if( sequence.length < seqLength ){ seqLength = sequence.length }

  for( var i=0; i<seqLength; i++ ){
    var residue = sequence.charAt(i).toUpperCase();
    // Check to see if FASTA header
    // If so, skip to next newline
    if( residue == '>' ){
      for( i=i++; i<seqLength; i++ ){
        residue = sequence.charAt(i);
        if( residue == '\\n' ){ break }
      }
    }

    // Find all the 123456789 chars 
    space_or_digit_found = space_or_digits.indexOf( residue )
    if( space_or_digit_found >= 0 ){ continue }
    if( residue == '\\n' ){ continue }
    if( residue == '\\t' ){ continue }

    // Find all the ACGTNX chars - valid bases
    // If it is not found the return value is -1
    base_found = bases.indexOf( residue );
    if ( base_found >= 0 ){ count++; }

    letters++;
  }

  percentage = ( count / letters ) * 100;

  var newQueryType = \"dna\";
  if( percentage < dna_threshold ){
    newQueryType = \"peptide\";
  }

  // Update the queryType radio group
  for( var i=0; i<document.settings.query.length; i++ ){
    document.settings.query[i].checked = false;
    if( document.settings.query[i].value == newQueryType ){
      document.settings.query[i].checked = true;
    }
  }
  changedQueryType();
}

//----------------------------------------------------------------------
// Returns the currently seleted seq type
//
function getQueryType(){
  if( ! document.settings.query ){ 
    alert( \"The query form element was not found\" );
    return;
  }
  var val = radioValue( document.settings.query );
  if( val ){ return val }
  return 'dna';
}

//----------------------------------------------------------------------
// Returns the currently seleted method
//
function getMethod(){
  if( ! document.settings.method ){ 
    alert( \"The method form element was not found\" );
    return;
  }
  return( selectValue( document.settings.method ) );
}

//----------------------------------------------------------------------
// Returns the currently seleted sensitivity
//
function getSensitivity(){
  if( ! document.settings.sensitivity ){ 
    alert( \"The sensitivity form element was not found\" );
    return;
  }
  return( selectValue( document.settings.sensitivity ) );
}

//----------------------------------------------------------------------
// Returns an array of the currently seleted species
//
function getSpecies(){
  // Make sure focus form exists
  if( ! document.settings.species ){ 
    alert( \"The species form element was not found\" );
    return;
  }
  return( selectValues( document.settings.species ) );
  //return( checkboxValues( document.settings.species ) );
}

//----------------------------------------------------------------------
// Returns the currently selected database type
//
function getDatabaseType(){
  if( ! document.settings.database ){ 
    alert( \"The database_type element was not found\" );
    return;
  }
  return( radioValue( document.settings.database ) );
}

//----------------------------------------------------------------------
// Returns the currently selected dna database
//
function getDatabaseDna(){
  var element = document.settings.database_dna;
  if( ! element ){ 
    alert( \"The 'database_dna' form element was not found\" );
    return;
  }
  return( selectValue( element ) );
}

//----------------------------------------------------------------------
// Returns the currently selected dna database
//
function getDatabasePeptide(){
  var element = document.settings.database_peptide;
  if( ! element ){ 
    alert( \"The 'database_peptide' form element was not found\" );
    return;
  }
  return( selectValue( element ) );
}

//----------------------------------------------------------------------
// Sets the queryType based on methodConf
//
function setQueryType(){
  var radio = document.settings.query;
  if( ! radio ){
    alert( \"The 'query' form element was not found\" );
    return;
  }
  for( var i=0; i<typeAry.length; i++ ){
    var queryType = typeAry[i];
    if( typeof getConf( queryType ) == 'object' ) {
      enableRadio( radio,  queryType );
    } else {
      disableRadio( radio,  queryType );
    }
  }
}

//----------------------------------------------------------------------
// Sets the method depending on query
function setMethod(){
  var qt    = getQueryType();
  var spAry = getSpecies();
  var dt    = getDatabaseType();
  var db;

  if( dt == \"dna\" )    { db = getDatabaseDna() }
  if( dt == \"peptide\" ){ db = getDatabasePeptide() }

  if( getMethod() != 0 ){ lastMethod = getMethod() }
  if( defaultMethod == undefined ){ defaultMethod = lastMethod }

  var selectGrp  = document.settings.method;
  var meValues = new Array();
  for( var j=0; j<spAry.length; j++ ){
    var sp = spAry[j];
    var meAry = new Array();
    for( var i=0; i<methodAry.length; i++ ){
      var me = methodAry[i];
      if( getConf( qt, sp, dt, db, me ) == 1 ) { meAry.push( me ); }
    }
    meValues.push( meAry );
  }
  meValues = arrayUnion( meValues );

  setSelectOptions( selectGrp, meValues, methodLabels, defaultMethod );
}

//----------------------------------------------------------------------
// Sets the sensitivity options depending on method
function setSensitivity(){
  var me = getMethod();

  if( getSensitivity() != 0 ){ lastSensitivity = getSensitivity() }
  if( defaultSensitivity == undefined ){ defaultSensitivity = lastSensitivity }

  var sensSelectGrp = document.settings.sensitivity;
  var sensValues = new Array();
  for( var i=0; i<sensitivityValues.length; i++ ){
    var sens = sensitivityValues[i];
    if( sensitivityConf[me][sens] ) { sensValues.push( sens ); }
  }
  setSelectOptions( sensSelectGrp, sensValues, sensitivityLabels, defaultSensitivity );
}

//----------------------------------------------------------------------
// Sets the species depending on query
//
function setSpecies(){

  var queryType  = getQueryType();
  var defSpecies = getSpecies(); 
  var control    = document.settings.species;
}

//----------------------------------------------------------------------
// Sets the database type depending on other opts and methodConf
//
function setDatabaseType(){
  var queryType    = getQueryType();
  var databaseType = getDatabaseType();
  var species      = getSpecies();

  if( databaseType == undefined ){ databaseType = lastDatabaseType }
  lastDatabaseType = databaseType;

  var radio     = document.settings.database;
  //var method    = getMethod();

  var enableAry  = new Array();
  var disableAry = new Array();

  for( var j=0; j<typeAry.length; j++ ){
    var dt = typeAry[j];
    var enabled = 1;

    if( ! species.length ) { disableAry.push( dt ); }
    else{
      for( var i=0; i<species.length; i++ ){
        var sp = species[i];
        if( typeof getConf( queryType, sp, dt ) != 'object' ) {
          disableAry.push( dt );
        } else {
          enableAry.push( dt );
        }
      }
    }
  }
  for( var i=0; i<enableAry.length; i++ ) {
    var isChecked = false;
    if( enableAry[i] == lastDatabaseType ) { isChecked = true }
    enableRadio( radio, enableAry[i], isChecked );
  }
  for( var i=0; i<disableAry.length; i++ ) { disableRadio( radio, disableAry[i] ); } 
}

//----------------------------------------------------------------------
// Sets the target DB options depending on other options
//
function setDatabase(){
  var nuclTargetDB = document.settings.database_dna;
  var protTargetDB = document.settings.database_peptide;

  // Create an array of selected species
  var selSpecies = getSpecies();
  var selQType   = getQueryType();

  var databaseDna     = getDatabaseDna();
  var databasePeptide = getDatabasePeptide();
  if( databaseDna     != 0 ){ lastDatabaseDna     = databaseDna     }
  if( databasePeptide != 0 ){ lastDatabasePeptide = databasePeptide }

  var optNuclValues = new Array();
  var optProtValues = new Array();
  for( var i=0; i<selSpecies.length; i++ ){
    var sp = selSpecies[i];

    var nAry = new Array();
    var pAry = new Array();

    for( var j=0; j<databaseAry.length; j++ ){
      var db = databaseAry[j];
      if( typeof getConf( selQType, sp, 'dna', db ) == 'object' ) { nAry.push( db ); }
      if( typeof getConf( selQType, sp, 'peptide', db ) == 'object' ) { pAry.push( db ); }
    }
    optNuclValues.push( nAry );  
    optProtValues.push( pAry );
  }
  var optNuclValues = arrayUnion( optNuclValues );
  var optProtValues = arrayUnion( optProtValues );
  var optNuclLabels = new Array();
  var optProtLabels = new Array();

  setSelectOptions( nuclTargetDB, optNuclValues, dbDnaLabels, lastDatabaseDna );
  setSelectOptions( protTargetDB, optProtValues, dbPeptideLabels, lastDatabasePeptide );

}
//--><!]]>
</script>
";

}

1;
