/**
    Copyright (c) 2016, Salesforce.org
    All rights reserved.
    
    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:
    
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Salesforce.org nor the names of
      its contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.
 
    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE 
    COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN 
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
    POSSIBILITY OF SUCH DAMAGE.
**/

@SuppressWarnings('PMD.AvoidGlobalModifier')
global abstract with sharing class PageControllerBase {
    private ComponentControllerBase componentController;

    public virtual ComponentControllerBase getComponentController() {
        return componentController;
    }

    public virtual void setComponentController(ComponentControllerBase compController) {
        componentController = compController;
    }

    public PageControllerBase getThis() {
        return this;
    }

    abstract global String getStrSoql();

    public List<String> strFields { get; set; }

    public String strNameField { get; set; }

    public String strObjectType { get; set; }

    abstract global PageReference newItem();

    public SoqlListView ctrlSoqlListView {
        get {
            if (ctrlSoqlListView == null) {
                ctrlSoqlListView = (SoqlListView) getComponentController();
            }
            return ctrlSoqlListView;
        }
        set;
    }

    public virtual PageReference editItem(Id idItem) {
        return new PageReference('/' + idItem + '/e?retURL=' + ApexPages.currentPage().getURL());
    }
}