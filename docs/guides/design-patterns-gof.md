# Design Patterns — Gang of Four (GoF) Catalog

> **Purpose**: the 23 Gang of Four patterns from *Design Patterns* (Gamma, Helm, Johnson, Vlissides, 1994), tailored to modern languages. Each entry has stable ID `CP-N` for citation.
>
> **Read first**: [`design-patterns.md`](design-patterns.md) — lead file with framing, descriptive-not-prescriptive caveats, and citation conventions. **Don't cite from this file without reading the lead file's "Read this first" section.** Patterns are vocabulary, not rules. Decorator, Iterator, Strategy, Command, Observer, and Template Method are mostly language features in modern languages — flagged per entry.

Examples are in Python, intentionally minimal. They show the shape of each pattern, not production code.

---

## Creational Patterns

How objects are created.

### CP2 — Singleton

**Intent**: one instance, global access point.

**When to use**: truly-single resources — hardware connection pool, configuration loaded once at startup, a process-wide logger sink.

**When NOT to use**: almost any other case. Global state hurts testability (every test that touches the singleton needs to reset it). Prefer dependency injection ([`CP27`](design-patterns-post-gof.md#cp27--dependency-injection-di)) and pass the instance explicitly. If the language gives you module-level state (Python modules, Go packages), that's already a singleton — don't wrap it.

```python
# Robust form: metaclass. __init__ runs exactly once.
class Singleton(type):
    _instances = {}
    def __call__(cls, *args, **kwargs):
        if cls not in cls._instances:
            cls._instances[cls] = super().__call__(*args, **kwargs)
        return cls._instances[cls]

class Logger(metaclass=Singleton):
    def __init__(self):
        self.sink = []   # runs only on first instantiation

# Textbook __new__ form (shown for recognition; has a footgun).
class LoggerNew:
    _instance = None
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    # Footgun: Python always calls __init__ after __new__ returns an
    # instance of cls. If __init__ is added later, it will run on every
    # LoggerNew() call and silently re-initialize state. Prefer the
    # metaclass form above, or guard __init__ with a flag set on first init.
```

### CP3 — Factory Method

**Intent**: define an interface for creating an object, but let subclasses decide the concrete type.

**When to use**: a base class can't anticipate the concrete type it needs (a `DocumentParser` whose subclasses know which engine to instantiate).

**When NOT to use**: when a plain function would do. In Python or JavaScript, "the factory" is often just a function returning an instance.

```python
class DocumentParser:
    def parse(self, path):
        return self._engine(path).parse()
    def _engine(self, path): raise NotImplementedError

class PDFParser(DocumentParser):
    def _engine(self, path): return PDFEngine(path)
```

### CP4 — Abstract Factory

**Intent**: create families of related objects without specifying concrete classes.

**When to use**: you need consistent groupings — a Mac UI needs Mac buttons *and* Mac scrollbars, a Windows UI needs Windows buttons *and* Windows scrollbars; mixing across families is a bug.

**When NOT to use**: when the families are not actually related (one factory per concern is simpler). Heavy ceremony if used speculatively.

```python
class UIFactory:
    def button(self): pass
    def scrollbar(self): pass

class MacFactory(UIFactory):
    def button(self): return MacButton()
    def scrollbar(self): return MacScrollbar()
```

### CP5 — Builder

**Intent**: construct a complex object step-by-step.

**When to use**: many optional parameters; avoid telescoping constructors. Common for query builders, HTTP request builders, complex configuration objects.

**When NOT to use**: when keyword arguments / named parameters do the job (Python, Kotlin, Swift). The builder pattern is largely Java boilerplate-tax mitigation.

```python
class QueryBuilder:
    def __init__(self): self._parts = {}
    def select(self, *cols): self._parts["select"] = cols; return self
    def where(self, cond): self._parts["where"] = cond; return self
    def build(self): return Query(**self._parts)

q = QueryBuilder().select("id", "name").where("active=1").build()
```

### CP6 — Prototype

**Intent**: create new objects by copying an existing instance.

**When to use**: object creation is expensive (DB lookup, heavy compute) and you need many near-copies that share initialization but vary in detail.

**When NOT to use**: when construction is cheap. `copy.deepcopy` (Python) or structured clone (JS) is the implementation; use the language's mechanism rather than implementing a custom `clone()` method.

```python
import copy
template = ExpensiveObject(loaded_from_db)
clone = copy.deepcopy(template)
clone.customize(...)
```

---

## Structural Patterns

How objects are composed.

### CP7 — Adapter

**Intent**: convert one interface into another the client expects.

**When to use**: integrating a third-party SDK whose API doesn't match the abstraction you've already standardized on internally.

**When NOT to use**: when you can change the interface that doesn't fit. Adapter is for interfaces you don't own.

```python
class StripeAdapter:  # makes Stripe match your PaymentProcessor interface
    def __init__(self, stripe): self._stripe = stripe
    def charge(self, amount, card):
        return self._stripe.PaymentIntent.create(amount=amount, source=card)
```

### CP8 — Bridge

**Intent**: decouple an abstraction from its implementation so both can vary independently.

**When to use**: you'd otherwise get a class explosion (`WinCircle`, `MacCircle`, `WinSquare`, `MacSquare`...). Split the cross-product into two axes: `Shape` × `Renderer`. Two axes mean N + M classes instead of N × M.

**When NOT to use**: when the cross-product is small (2×2). The indirection cost outweighs the saving.

```python
class Shape:
    def __init__(self, renderer): self.renderer = renderer
class Circle(Shape):
    def draw(self): self.renderer.render_circle(self)

class VectorRenderer:
    def render_circle(self, c): ...
class RasterRenderer:
    def render_circle(self, c): ...
```

### CP9 — Composite

**Intent**: treat individual objects and groups uniformly via a tree.

**When to use**: part-whole hierarchies — file systems, UI trees, org charts, AST nodes.

**When NOT to use**: when the structure is naturally flat (a list). Composite is for genuinely recursive structures.

```python
class FSNode:
    def size(self): pass
class File(FSNode):
    def size(self): return self._bytes
class Directory(FSNode):
    def size(self): return sum(c.size() for c in self.children)
```

### CP10 — Decorator

**Intent**: add responsibilities to an object dynamically without subclassing.

**When to use**: cross-cutting concerns layered per-instance — logging, caching, auth, compression. Python's `@decorator` syntax is this pattern at the function level (language-feature absorption — see [§"Read this first"](design-patterns.md#read-this-first--descriptive-vocabulary-not-prescription) in the lead file).

**When NOT to use**: when the responsibilities are static and known at compile time (subclassing is simpler). Don't reach for runtime composition for what could be a stable inheritance tree.

```python
def with_cache(fn):
    cache = {}
    def wrapper(*args):
        # Positional-only for example clarity. A real cache that
        # accepts **kwargs needs a hashable key like
        # (args, tuple(sorted(kwargs.items()))) — or just use
        # functools.lru_cache / functools.cache.
        if args not in cache: cache[args] = fn(*args)
        return cache[args]
    return wrapper

@with_cache
def slow_lookup(key): ...
```

### CP11 — Facade

**Intent**: simple, unified interface over a complex subsystem.

**When to use**: wrapping a messy library or several internal services in one clean entry point. The README's quickstart often *is* a facade.

**When NOT to use**: when the underlying API is already simple. Don't add a facade just to rename methods — that's noise.

```python
class VideoConverter:  # facade hiding codec/bitrate/muxer machinery
    def convert(self, file, fmt):
        codec = CodecFactory.create(fmt)
        rate = BitrateCalculator.optimal(file)
        return Muxer(codec, rate).process(file)
```

### CP12 — Flyweight

**Intent**: share fine-grained objects to reduce memory.

**When to use**: huge numbers of similar objects with shared intrinsic state — game particles, characters in a text editor, map tiles, tokens in a tokenizer's vocabulary.

**When NOT to use**: when the object count is small or the per-object state is mostly extrinsic (no sharing benefit). Memory micro-optimization that costs you mutability semantics.

```python
class GlyphFactory:
    _cache = {}
    @classmethod
    def get(cls, char):
        if char not in cls._cache:
            cls._cache[char] = Glyph(char)  # immutable, shared
        return cls._cache[char]
```

### CP13 — Proxy

**Intent**: surrogate controlling access to another object.

**When to use**: lazy loading (don't fetch until accessed), access control (check permissions on every call), caching (return cached result without hitting the real object), remote objects (RPC stubs).

**When NOT to use**: when the wrapped object is already cheap. Wrapping a fast in-memory object in a proxy adds an indirection for no gain.

```python
class ImageProxy:
    def __init__(self, path): self.path = path; self._real = None
    def display(self):
        if self._real is None:
            self._real = HighResImage(self.path)  # load on demand
        self._real.display()
```

---

## Behavioral Patterns

How objects communicate and assign responsibility.

### CP14 — Chain of Responsibility

**Intent**: pass a request along a chain; each handler decides to handle or pass.

**When to use**: middleware stacks (auth → logging → rate limit → handler), exception chains, approval workflows where the rule "first applicable rule wins" governs.

**When NOT to use**: when the request has a known target. Don't build a chain to dispatch what `dict[key]` could do.

```python
class Handler:
    def __init__(self, successor=None): self.successor = successor
    def handle(self, req):
        if self.successor: return self.successor.handle(req)

chain = Auth(Logging(RateLimit(BusinessLogic())))
chain.handle(request)
```

### CP15 — Command

**Intent**: wrap a request as an object — parameterizable, queueable, undoable.

**When to use**: undo/redo stacks, transaction queues, macro recording, job scheduling, event sourcing (see [`CP30`](design-patterns-post-gof.md#cp30--event-sourcing)).

**When NOT to use**: when a closure or partial application does the job. In any language with first-class functions, "Command" often collapses to a callable (language-feature absorption).

```python
class Command:
    def execute(self): pass
    def undo(self): pass

class DeleteCommand(Command):
    def __init__(self, doc): self.doc = doc
    def execute(self): self.backup = self.doc.text; self.doc.clear()
    def undo(self): self.doc.text = self.backup
```

### CP16 — Interpreter

**Intent**: define a grammar and an interpreter for sentences in it.

**When to use**: rarely. Small embedded DSLs (filter expressions, simple rule engines).

**When NOT to use**: anything beyond trivial. Use a parser library (Lark, ANTLR, PEG) — hand-rolling an interpreter for a non-trivial grammar is a maintenance trap. This is one of the GoF patterns most likely to be an anti-pattern today.

```python
class Expr:
    def evaluate(self, ctx): pass
class And(Expr):
    def __init__(self, l, r): self.l, self.r = l, r
    def evaluate(self, ctx): return self.l.evaluate(ctx) and self.r.evaluate(ctx)
```

### CP17 — Iterator

**Intent**: sequential access to elements without exposing internal structure.

**When to use**: custom collections that need a non-trivial traversal (tree walks, graph traversals, lazy streams).

**When NOT to use**: anything the language gives you for free. In Python, this is `__iter__` / `__next__` and is built into the language; in Java/C#/JS, the language's iteration protocol covers most cases (language-feature absorption — flagged in lead file).

```python
class TreeIterator:
    def __init__(self, root): self.stack = [root]
    def __iter__(self): return self
    def __next__(self):
        if not self.stack: raise StopIteration
        node = self.stack.pop()
        # reversed() so left children are popped first — standard
        # left-to-right depth-first / document-order traversal.
        self.stack.extend(reversed(node.children))
        return node
```

### CP18 — Mediator

**Intent**: centralize complex object-to-object communication so they don't reference each other directly.

**When to use**: UI dialogs where many widgets affect each other; chat rooms; air-traffic-control–style coordination.

**When NOT to use**: when the mediator becomes a god object that contains all the logic the participants used to have. Mediator is a place to put coordination, not all behavior.

```python
class DialogMediator:
    def widget_changed(self, widget):
        if widget is self.checkbox:
            self.textfield.enabled = self.checkbox.checked
# Widgets only know the mediator, not each other.
```

### CP19 — Memento

**Intent**: capture and restore an object's state without breaking encapsulation.

**When to use**: undo, save points, snapshots, transactional rollback.

**When NOT to use**: when the state is large (memento explodes memory) or already serializable through normal channels. Don't reach for memento if `pickle.dumps(self)` works.

```python
class Editor:
    def save(self): return Memento(self.text)
    def restore(self, m): self.text = m.state
```

### CP20 — Observer

**Intent**: one-to-many dependency — when subject changes, observers are notified.

**When to use**: event systems, pub/sub, reactive UIs, model-view sync. The most foundational pattern for event-driven code.

**When NOT to use**: when you need ordered, transactional, or guaranteed delivery — observer is fire-and-forget. Use a message queue. Most modern languages and frameworks ship observer-shaped APIs (event emitters, signals, reactive streams) — language-feature absorption.

```python
class Subject:
    def __init__(self): self.observers = []
    def subscribe(self, o): self.observers.append(o)
    def notify(self, event):
        for o in self.observers: o.update(event)
```

### CP21 — State

**Intent**: behavior changes when internal state changes — looks like the object changed class.

**When to use**: replacing large state-driven `if`/`switch` blocks. TCP connections, order workflows, document approval, anything modeled as a state machine.

**When NOT to use**: when the states are few (2–3) and the transitions are simple. A flag and an `if` is fine; don't add classes per state speculatively.

```python
class Order:
    def cancel(self): self.state.cancel(self)

class Pending:
    def cancel(self, order): order.state = Cancelled()
class Shipped:
    def cancel(self, order): raise CannotCancel("already shipped")
```

### CP22 — Strategy

**Intent**: encapsulate interchangeable algorithms; pick one at runtime.

**When to use**: sorting, compression, pricing, routing — anywhere you need to swap "how" without changing "what."

**When NOT to use**: when a function passed as a parameter does the same job. In Python or JavaScript, "Strategy" is often just `lambda` or a function reference — don't write a Strategy interface and concrete classes when the language gives you the shape (language-feature absorption — flagged in lead file).

```python
class Cart:
    def __init__(self, discount): self.discount = discount
    def total(self, items):
        return self.discount(sum(i.price for i in items))

def black_friday(total): return total * 0.5
cart = Cart(black_friday)
```

### CP23 — Template Method

**Intent**: skeleton of an algorithm in a base class; subclasses fill in steps.

**When to use**: several classes share an algorithm structure but differ in specific steps. Common in frameworks ("call us, we'll call you").

**When NOT to use**: when composition (passing the differing steps as functions or strategy objects — see [`CP22`](#cp22--strategy)) is cleaner. Inheritance-based template method couples subclasses to the parent's algorithm shape; later changes to the parent's shape break every subclass. In any language with decorators or function composition, the pattern often collapses to a higher-order function (language-feature absorption).

```python
class ReportGenerator:
    def generate(self):
        data = self.fetch()
        formatted = self.format(data)
        self.publish(formatted)
    def fetch(self): raise NotImplementedError
    def format(self, d): raise NotImplementedError
    def publish(self, f): print(f)  # default
```

### CP24 — Visitor

**Intent**: add new operations to an object structure without modifying the classes themselves.

**When to use**: stable class hierarchy, frequently changing operations. Classic example: compiler ASTs (type-check visitor, codegen visitor, optimization visitor — all over the same node types).

**When NOT to use**: when the class hierarchy itself changes often. Visitor inverts normal OO: adding a new operation is cheap (one new visitor), but adding a new node type is expensive (every visitor needs updating). If the node types are unstable, visitor is the wrong shape. In languages with pattern matching (Scala, Rust, modern Python via `match`), pattern matching often subsumes visitor.

```python
class NumberNode:
    def accept(self, v): return v.visit_number(self)

class PrintVisitor:
    def visit_number(self, n): print(n.value)
class EvalVisitor:
    def visit_number(self, n): return n.value
```

---

## Cross-references

- [`design-patterns.md`](design-patterns.md) — lead file, framing and `CAP1` / `CAP2` / `CP1`.
- [`design-patterns-post-gof.md`](design-patterns-post-gof.md) — sibling file, `CP25`–`CP34`.
- [`.context/rules/repo_orchestration_patterns.md`](../../.context/rules/repo_orchestration_patterns.md) — orchestration-layer patterns for *this* template.
