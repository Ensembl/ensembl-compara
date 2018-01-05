/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * Copyright [2016-2018] EMBL-European Bioinformatics Institute
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *      http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#define Inline_Stack_Vars dXSARGS
#define Inline_Stack_Items items
#define Inline_Stack_Item(x) ST(x)
#define Inline_Stack_Reset sp = mark
#define Inline_Stack_Push(x) XPUSHs(x)
#define Inline_Stack_Done PUTBACK
#define Inline_Stack_Return(x) XSRETURN(x)
#define Inline_Stack_Void XSRETURN(0)

#define INLINE_STACK_VARS Inline_Stack_Vars
#define INLINE_STACK_ITEMS Inline_Stack_Items
#define INLINE_STACK_ITEM(x) Inline_Stack_Item(x)
#define INLINE_STACK_RESET Inline_Stack_Reset
#define INLINE_STACK_PUSH(x) Inline_Stack_Push(x)
#define INLINE_STACK_DONE Inline_Stack_Done
#define INLINE_STACK_RETURN(x) Inline_Stack_Return(x)
#define INLINE_STACK_VOID Inline_Stack_Void

#define inline_stack_vars Inline_Stack_Vars
#define inline_stack_items Inline_Stack_Items
#define inline_stack_item(x) Inline_Stack_Item(x)
#define inline_stack_reset Inline_Stack_Reset
#define inline_stack_push(x) Inline_Stack_Push(x)
#define inline_stack_done Inline_Stack_Done
#define inline_stack_return(x) Inline_Stack_Return(x)
#define inline_stack_void Inline_Stack_Void
