#!/usr/bin/env python

import dbus
import xml.etree.ElementTree as ElementTree

from efl import evas
from efl import elementary as elm
from efl.elementary.window import StandardWindow
from efl.elementary.background import Background
from efl.elementary.box import Box
from efl.elementary.button import Button
from efl.elementary.flipselector import FlipSelector
from efl.elementary.panes import Panes
from efl.elementary.genlist import Genlist, GenlistItem, GenlistItemClass
from efl.dbus_mainloop import DBusEcoreMainLoop


### connect to session and system buses, and set session as the current one
session_bus = dbus.SessionBus(mainloop=DBusEcoreMainLoop())
system_bus = dbus.SystemBus(mainloop=DBusEcoreMainLoop())
bus = session_bus


### Classes to describe various DBus nodes
class DBusNode(object):
    """base object for the others DBus nodes"""
    def __init__(self, name, parent):
        self._name = name
        self._parent = parent

    @property
    def name(self):
        return self._name
    
    @property
    def parent(self):
        return self._parent


class DBusObject(DBusNode):
    """object to represent a DBus Object """
    def __init__(self, name, parent_service):
        DBusNode.__init__(self, name, parent_service)
        self._interfaces = []

    @property
    def interfaces(self):
        return self._interfaces


class DBusInterface(DBusNode):
    """object to represent a DBus Interface"""
    def __init__(self, name, parent_obj):
        DBusNode.__init__(self, name, parent_obj)
        self._properties = []
        self._methods = []
        self._signals = []
        
        parent_obj.interfaces.append(self)
    
    @property
    def properties(self):
        return self._properties
    
    @property
    def methods(self):
        return self._methods
    
    @property
    def signals(self):
        return self._signals


class DBusProperty(DBusNode):
    """object to represent a DBus Property"""
    def __init__(self, name, parent_iface, typ = 'unknown', access = 'unknown'):
        DBusNode.__init__(self, name, parent_iface)
        parent_iface.properties.append(self)
        self._type = typ
        self._access = access

    @property
    def type(self):
        return self._type

    @property
    def access(self):
        return self._access

class DBusMethod(DBusNode):
    """object to represent a DBus Method"""
    def __init__(self, name, parent_iface):
        DBusNode.__init__(self, name, parent_iface)
        parent_iface.methods.append(self)
        self._params = []
        self._returns = []

    @property
    def params(self):
        return self._params

    @property
    def params_str(self):
        return ', '.join([(ty+' '+name).strip() for name, ty in self._params])

    @property
    def returns(self):
        return self._returns

    @property
    def returns_str(self):
        return ', '.join([(ty+' '+name).strip() for name, ty in self._returns])

class DBusSignal(DBusNode):
    """object to represent a DBus Signal"""
    def __init__(self, name, parent_iface):
        DBusNode.__init__(self, name, parent_iface)
        parent_iface.signals.append(self)
        self._params = []

    @property
    def params(self):
        return self._params

    @property
    def params_str(self):
        return ', '.join([(ty+' '+name).strip() for name, ty in self._params])


### Introspect a named service and return a list of DBusObjects
def recursive_introspect(bus, named_service, object_path, ret_data=None):

    # first recursion, create an empty list
    if ret_data is None:
        ret_data = []

    # parse the xml string from the Introspectable interface
    obj = bus.get_object(named_service, object_path)
    iface = dbus.Interface(obj, 'org.freedesktop.DBus.Introspectable')
    xml_data = iface.Introspect()
    xml_root = ElementTree.fromstring(xml_data)

    # debug
    print('=' * 80)
    print("Introspecting path:'%s' on service:'%s'" % (object_path, named_service))
    print('=' * 80)
    print(xml_data)
    print('=' * 80)

    # traverse the xml tree
    if xml_root.find('interface'):
        # found a new object
        obj = DBusObject(object_path, named_service)
        ret_data.append(obj)
    
    for xml_node in xml_root:
        # found an interface
        if xml_node.tag == 'interface':
            iface = DBusInterface(xml_node.attrib['name'], obj)

            for child in xml_node:
                if child.tag == 'property':
                    typ = child.attrib['type']
                    access = child.attrib['access']
                    prop = DBusProperty(child.attrib['name'], iface, typ, access)

                if child.tag == 'method':
                    meth = DBusMethod(child.attrib['name'], iface)
                    for arg in child:
                        if arg.tag == 'arg':
                            if arg.attrib['direction'] == 'out':
                                L = meth.returns
                            else:
                                L = meth.params
                            L.append((
                                arg.attrib['name'] if 'name' in arg.attrib else '',
                                arg.attrib['type'] if 'type' in arg.attrib else ''))

                if child.tag == 'signal':
                    sig = DBusSignal(child.attrib['name'], iface)
                    for arg in child:
                        if arg.tag == 'arg':
                            sig.params.append((
                                arg.attrib['name'] if 'name' in arg.attrib else '',
                                arg.attrib['type'] if 'type' in arg.attrib else ''))

        # found another node, introspect it...
        if xml_node.tag == 'node':
            if object_path == '/':
                object_path = ''
            new_path = '/'.join((object_path, xml_node.attrib['name']))
            recursive_introspect(bus, named_service, new_path, ret_data)

    return ret_data


### Names genlist (the one on the left)
class NamesListGroupItemClass(GenlistItemClass):
    def __init__(self):
        GenlistItemClass.__init__(self, item_style="group_index")
    def text_get(self, gl, part, name):
        return name

class NamesListItemClass(GenlistItemClass):
    def __init__(self):
        GenlistItemClass.__init__(self, item_style="default")
    def text_get(self, gl, part, name):
        return name

class NamesList(Genlist):
    def __init__(self, parent):

        self.win = parent
        self.sig1 = None

        # create the genlist
        Genlist.__init__(self, parent)
        self.itc = NamesListItemClass()
        self.itc_g = NamesListGroupItemClass()
        self.callback_selected_add(self.item_selected_cb)

        # add private & public group items
        self.public_group = self.item_append(self.itc_g, "Public Services",
                               flags=elm.ELM_GENLIST_ITEM_GROUP)
        self.public_group.select_mode_set(elm.ELM_OBJECT_SELECT_MODE_DISPLAY_ONLY)
        
        self.private_group = self.item_append(self.itc_g, "Private Services",
                               flags=elm.ELM_GENLIST_ITEM_GROUP)
        self.private_group.select_mode_set(elm.ELM_OBJECT_SELECT_MODE_DISPLAY_ONLY)

        # populate the genlist
        self.populate()

    def populate(self):
        for name in bus.list_names():
            self.service_add(name)

        # keep the list updated when a name changes
        if self.sig1: self.sig1.remove()
        self.sig1 = bus.add_signal_receiver(self.name_owner_changed_cb, 
                                            "NameOwnerChanged")
        # bus.add_signal_receiver(self.name_acquired_cb, "NameAcquired")
        # bus.add_signal_receiver(self.name_lost_cb, "NameLost")
    
    def clear(self):
        self.public_group.subitems_clear()
        self.private_group.subitems_clear()

    def item_selected_cb(self, gl, item):
        name = item.data
        self.win.detail_list.populate(name)
    
    def sort_cb(self, it1, it2):
        return 1 if it1.data.lower() < it2.data.lower() else -1
        

    def service_add(self, name):
        print("service_add('%s')" % name)
        if name.startswith(":"):
            self.item_sorted_insert(self.itc, name, self.sort_cb,
                                    self.private_group, 0, None)
        else:
            self.item_sorted_insert(self.itc, name, self.sort_cb,
                                    self.public_group, 0, None)
    def service_del(self, name):
        print("service_del('%s')" % name)
        item = self.first_item
        while item:
            if item.data == name:
                item.delete()
                return
            item = item.next
        
    def name_owner_changed_cb(self, name, old_owner, new_owner):
        print("NameOwnerChanged(name='%s', old_owner='%s', new_owner='%s')" %
              (name, old_owner, new_owner))
        if old_owner == '':
            self.service_add(name)
        elif new_owner == '':
            self.service_del(name)


### Detail genlist (the one on the right)
class ObjectItemClass(GenlistItemClass):
    def __init__(self):
        GenlistItemClass.__init__(self, item_style="group_index")
    def text_get(self, gl, part, obj):
        return '[OBJ] ' + obj.name

class NodeItemClass(GenlistItemClass):
    def __init__(self):
        GenlistItemClass.__init__(self, item_style="default")
    def text_get(self, gl, part, obj):
        if isinstance(obj, DBusInterface):
            return '[IFACE] ' + obj.name
        if isinstance(obj, DBusProperty):
            return '[PROP] %s %s (%s)' % (obj.type, obj.name, obj.access)
        if isinstance(obj, DBusMethod):
            params = obj.params_str
            rets = obj.returns_str
            if rets:
                return '[METH] %s(%s) -> (%s)' % (obj.name, params, rets)
            else:
                return '[METH] %s(%s)' % (obj.name, params)
        if isinstance(obj, DBusSignal):
            return '[SIG] %s(%s)' % (obj.name, obj.params_str)

class DetailList(Genlist):
    def __init__(self, parent):
        Genlist.__init__(self, parent)
        self.itc = NodeItemClass()
        self.itc_g = ObjectItemClass()
        self.callback_expand_request_add(self.expand_request_cb)
        self.callback_expanded_add(self.expanded_cb)
        self.callback_contract_request_add(self.contract_request_cb)
        self.callback_contracted_add(self.contracted_cb)
        
        
    def populate(self, name):
        print("populate: %s" % name)
        self.clear()

        # objects
        for obj in recursive_introspect(bus, name, '/'):
            obj_item = self.item_append(self.itc_g, obj,
                                        flags=elm.ELM_GENLIST_ITEM_GROUP)
            obj_item.select_mode_set(elm.ELM_OBJECT_SELECT_MODE_DISPLAY_ONLY)
            
            # interfaces
            for iface in obj.interfaces:
                iface_item = self.item_append(self.itc, iface,
                                              parent_item=obj_item,
                                              flags=elm.ELM_GENLIST_ITEM_TREE)

    def sort_cb(self, it1, it2):
        pri1 = pri2 = 0
        if isinstance(it1.data, DBusProperty): pri1 = 3
        elif isinstance(it1.data, DBusMethod): pri1 = 2
        elif isinstance(it1.data, DBusSignal): pri1 = 1
        if isinstance(it2.data, DBusProperty): pri2 = 3
        elif isinstance(it2.data, DBusMethod): pri2 = 2
        elif isinstance(it2.data, DBusSignal): pri2 = 1
        if pri1 > pri2: return 1
        elif pri1 < pri2: return -1
        return 1 if it1.data.name.lower() < it2.data.name.lower() else -1

    def expand_request_cb(self, genlist, item):
        item.expanded = True

    def expanded_cb(self, genlist, item):
        iface = item.data
        for obj in iface.properties + iface.methods + iface.signals:
            self.item_sorted_insert(self.itc, obj, self.sort_cb, parent_item=item)
    
    def contract_request_cb(self, genlist, item):
        item.expanded = False

    def contracted_cb(self, genlist, item):
        item.subitems_clear()


### The main window
class MyWin(StandardWindow):
    def __init__(self):
        StandardWindow.__init__(self, "efl-dbus-spy", "EFL DBus Spy - Espionage")

        self.autodel_set(True)
        self.callback_delete_request_add(lambda o: elm.exit())

        bg = Background(self)
        self.resize_object_add(bg)
        bg.size_hint_weight_set(evas.EVAS_HINT_EXPAND, evas.EVAS_HINT_EXPAND)
        bg.show()

        box = Box(self)
        self.resize_object_add(box)
        box.size_hint_weight_set(evas.EVAS_HINT_EXPAND, evas.EVAS_HINT_EXPAND)
        box.show()
        
        flip = FlipSelector(self)
        flip.item_append("Session Bus", self.flip_selected_cb, session_bus)
        flip.item_append("System Bus", self.flip_selected_cb, system_bus)
        box.pack_end(flip)
        flip.show()
        
        panes = Panes(self)
        panes.size_hint_weight = (evas.EVAS_HINT_EXPAND, evas.EVAS_HINT_EXPAND)
        panes.size_hint_align = (evas.EVAS_HINT_FILL, evas.EVAS_HINT_FILL)
        # panes.content_left_size = 0.333
        # panes.fixed = True
        box.pack_end(panes)
        panes.show()

        self.names_list = NamesList(self)
        panes.part_content_set("left", self.names_list)
        self.names_list.show()

        self.detail_list = DetailList(self)
        panes.part_content_set("right", self.detail_list)
        self.detail_list.show()

        self.resize(700, 500)
        self.show()

    def flip_selected_cb(self, flipselector, item, selected_bus):
        global bus

        bus = selected_bus
        self.detail_list.clear()
        self.names_list.clear()
        self.names_list.populate()


if __name__ == "__main__":
    elm.init()
    win = MyWin()
    elm.run()
    elm.shutdown()

